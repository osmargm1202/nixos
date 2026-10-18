#!@python@/bin/python3
"""Interactive, root-only reader test on a private bus; never changes PAM/units."""
import os
from pathlib import Path
import pwd
import selectors
import shutil
import subprocess
import sys
import tempfile
import time

FPRINTD = Path('@fprintd@')
DBUS = Path('@dbus@')
POLKIT = Path('@polkit@')
STATE = Path('/var/lib/fprint-synatudor-test')
FINGER = 'right-index-finger'


def private_state(path):
    if path.is_symlink():
        raise RuntimeError('El directorio de estado no puede ser un enlace')
    path.mkdir(mode=0o700, exist_ok=True)
    info = path.stat()
    if info.st_uid != 0 or info.st_mode & 0o077:
        raise RuntimeError('El estado debe pertenecer a root y tener permisos 0700')


def bus_config(socket):
    # Only root clients and the real polkit daemon can connect. No service
    # directories: nothing from the host system bus can be auto-activated here.
    return f'''<busconfig>
  <type>system</type>
  <listen>unix:path={socket}</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <deny user="*"/>
    <allow user="root"/>
    <allow user="polkituser"/>
    <deny own="*"/>
    <deny send_destination="*"/>
  </policy>
  <policy user="root">
    <allow own="*"/><allow send_destination="*"/><allow receive_sender="*"/>
  </policy>
  <policy user="polkituser">
    <allow own="org.freedesktop.PolicyKit1"/><allow send_destination="*"/>
    <allow receive_sender="*"/>
  </policy>
</busconfig>'''


def stop(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def client(args, env, timeout=180, allow_rejection=False):
    """Stream CLI progress, bound runtime, and inspect semantic result codes."""
    process = subprocess.Popen(args, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)
    data = bytearray()
    deadline = time.monotonic() + timeout
    try:
        with selectors.DefaultSelector() as poll:
            poll.register(process.stdout, selectors.EVENT_READ)
            while True:
                if time.monotonic() >= deadline:
                    raise RuntimeError('Tiempo agotado; no se reinicia ni borra el sensor')
                if not poll.select(timeout=1):
                    continue
                chunk = os.read(process.stdout.fileno(), 4096)
                if not chunk:
                    break
                data.extend(chunk)
                print(chunk.decode('utf-8', 'replace'), end='', flush=True)
        result = process.wait(timeout=10)
        text = data.decode('utf-8', 'replace')
        rejected = (allow_rejection and result == 1
                    and result_tokens(text)
                    and result_tokens(text)[-1] == 'verify-no-match'
                    and 'verify-match' not in result_tokens(text))
        if result and not rejected:
            raise RuntimeError(f'El cliente terminó con código {result}')
        return text
    finally:
        stop(process)
        process.stdout.close()


def result_tokens(text):
    # verify.c prints "Verify result: verify-match (done)". Compare full
    # tokens, never substrings, and require the final result to match.
    return [line.split(':', 1)[1].split()[0] for line in text.splitlines()
            if line.startswith(('Enroll result:', 'Verify result:'))
            and line.split(':', 1)[1].split()]


def require_result(text, expected):
    results = result_tokens(text)
    if not results or results[-1] != expected:
        raise RuntimeError(f'No se obtuvo {expected}; no se continúa')


def wait_name(name, env, children):
    command = [str(DBUS/'bin/dbus-send'), '--system', '--print-reply',
               '--reply-timeout=1000', '--dest=org.freedesktop.DBus',
               '/org/freedesktop/DBus', 'org.freedesktop.DBus.NameHasOwner',
               f'string:{name}']
    for _ in range(100):
        if any(p.poll() is not None for p in children):
            raise RuntimeError('Un daemon de prueba terminó antes de estar listo')
        reply = subprocess.run(command, env=env, capture_output=True,
                               text=True, timeout=3)
        if reply.returncode == 0 and 'boolean true' in reply.stdout:
            return
        time.sleep(0.1)
    raise RuntimeError(f'No apareció {name} en el bus privado')


def main():
    if len(sys.argv) != 2 or os.geteuid() != 0 or not sys.stdin.isatty():
        raise RuntimeError('Uso desde una terminal: sudo envy-fingerprint-test USUARIO')
    user = sys.argv[1]
    if pwd.getpwnam(user).pw_uid == 0:
        raise RuntimeError('Indica el usuario normal que registrará la huella')
    # Refuse a competing experimental system backend. Stock fprintd does not
    # support this sensor; it and all host authentication remain untouched.
    unit = subprocess.run(['/run/current-system/sw/bin/systemctl', 'show',
                           'fprintd.service', '-p', 'ExecStart', '--value'],
                          capture_output=True, text=True, check=True)
    if 'synatudor' in unit.stdout.lower():
        raise RuntimeError('Ya hay un backend experimental del sistema; detener esta prueba')
    private_state(STATE)
    runtime = Path(tempfile.mkdtemp(prefix='fp-test-', dir='/run'))
    runtime.chmod(0o755)  # polkituser must reach the socket; bus UID policy gates access.
    logfile = STATE/'probe.log'
    children = []
    try:
        config = runtime/'bus.conf'
        config.write_text(bus_config(runtime/'bus'))
        env = {'PATH': '/run/current-system/sw/bin', 'LC_ALL': 'C',
               'HOME': '/var/empty',
               'DBUS_SYSTEM_BUS_ADDRESS': f'unix:path={runtime}/bus'}
        with logfile.open('ab', buffering=0) as log:
            bus = subprocess.Popen([str(DBUS/'bin/dbus-daemon'), '--nofork',
                                    f'--config-file={config}'], env=env,
                                   stdout=log, stderr=log)
            children.append(bus)
            wait_name('org.freedesktop.DBus', env, children)
            (runtime/'bus').chmod(0o666)  # EXTERNAL credentials + UID policy, not filesystem ACL.
            account = pwd.getpwnam('polkituser')
            authority = subprocess.Popen(
                [str(POLKIT/'lib/polkit-1/polkitd'), '--no-debug', '--log-level=warning'],
                env=env, stdout=log, stderr=log, user=account.pw_uid,
                group=account.pw_gid, extra_groups=[])
            children.append(authority)
            wait_name('org.freedesktop.PolicyKit1', env, children)

            def start_reader():
                daemon = subprocess.Popen([str(FPRINTD/'libexec/fprintd'), '--no-timeout'],
                    env=env | {'STATE_DIRECTORY': str(STATE),
                               'FP_DRIVERS_ALLOWLIST': 'synatlsmoc'},
                    stdout=log, stderr=log)
                children.append(daemon)
                wait_name('net.reactivated.Fprint', env, children)
                return daemon

            print('Bus privado preparado. No se modifica PAM, SDDM, servicios ni arranque.')
            print('Abrir el lector puede cambiar su emparejamiento. NO se formatea ni actualiza.')
            input('Pulsa Enter para abrir el lector, o Ctrl+C para cancelar: ')
            daemon = start_reader()
            listing = client([str(FPRINTD/'bin/fprintd-list'), user], env, timeout=30)
            if 'No devices available' in listing or 'Using device' not in listing:
                raise RuntimeError('El backend no encontró un lector disponible')
            if FINGER not in listing:
                input('Prepara el ÍNDICE DERECHO. Pulsa Enter y tócalo repetidamente cuando se indique: ')
                enrolled = client([str(FPRINTD/'bin/fprintd-enroll'), '-f', FINGER, user], env)
                require_result(enrolled, 'enroll-completed')
            else:
                print('Ya existe un índice derecho en este estado; NO se reemplaza ni borra.')
            input('Prueba positiva: prepara el ÍNDICE DERECHO y pulsa Enter: ')
            matched = client([str(FPRINTD/'bin/fprintd-verify'), '-f', FINGER, user], env, timeout=60)
            require_result(matched, 'verify-match')
            input('Prueba negativa: prepara OTRO DEDO y pulsa Enter: ')
            rejected = client([str(FPRINTD/'bin/fprintd-verify'), '-f', FINGER, user], env,
                              timeout=60, allow_rejection=True)
            require_result(rejected, 'verify-no-match')
            if 'verify-match' in result_tokens(rejected):
                raise RuntimeError('Se aceptó el otro dedo; NO usar esta huella para autenticación')
            stop(daemon)
            children.remove(daemon)
            start_reader()
            input('Persistencia tras reiniciar solo el daemon: prepara el ÍNDICE DERECHO y pulsa Enter: ')
            persisted = client([str(FPRINTD/'bin/fprintd-verify'), '-f', FINGER, user], env, timeout=60)
            require_result(persisted, 'verify-match')
            print('OK: registro, coincidencia, rechazo y persistencia tras reinicio del daemon.')
    finally:
        for process in reversed(children):
            stop(process)
        shutil.rmtree(runtime)
        print(f'Prueba terminada. Estado/registro privados conservados en {STATE}.')
        print('El backend del sistema y la autenticación no se han cambiado.')


if __name__ == '__main__':
    os.umask(0o077)
    try:
        main()
    except KeyboardInterrupt:
        print('\nCancelado. No se borra el estado del sensor.', file=sys.stderr)
        sys.exit(130)
    except (RuntimeError, OSError, KeyError, subprocess.SubprocessError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        print(f'Log privado: {STATE}/probe.log. No compartir completo sin sanear.', file=sys.stderr)
        sys.exit(1)
