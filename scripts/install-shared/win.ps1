$OdinRoot = odin root
$OdinShared = "$OdinRoot\shared"

Set-Location $OdinShared

Remove-Item -Recurse -Force -ErrorAction SilentlyContinue http

git clone https://github.com/laytan/odin-http.git
Move-Item .\odin-http .\http
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue odin-http
& "$PSScriptRoot\..\install-luajit\win.cmd"
