param([Parameter(Mandatory)][ValidatePattern('^\d+x\d+$')][string]$Resolution)

$ErrorActionPreference = 'Stop'
$options = "/d /v:off /c Fiefdom-Compatibility.cmd --windowed --resolution $Resolution --disable-vsync --fixed-fps 60 --quit-after 180 --log-file ../compatibility-title.log"
$launcher = Start-Process -FilePath $env:ComSpec -ArgumentList $options -WorkingDirectory $PWD.Path -WindowStyle Hidden -Wait -PassThru
exit $launcher.ExitCode
