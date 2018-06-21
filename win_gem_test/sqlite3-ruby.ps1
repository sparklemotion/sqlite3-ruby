# PowerShell script for building & testing SQLite3-Ruby fat binary gem
# Code by MSP-Greg, see https://github.com/MSP-Greg/av-gem-build-test

# load utility functions, pass 64 or 32
. $PSScriptRoot\shared\appveyor_setup.ps1 $args[0]
if ($LastExitCode) { exit }

# above is required code
#———————————————————————————————————————————————————————————————— above for all repos

Make-Const gem_name  'sqlite3'
Make-Const repo_name 'sqlite3-ruby'
Make-Const url_repo  'https://github.com/sparklemotion/sqlite3-ruby.git'

#———————————————————————————————————————————————————————————————— lowest ruby version
Make-Const ruby_vers_low 20

#———————————————————————————————————————————————————————————————— SQLite package info
$sql_vers = '3240000'
$sql_year = '2018'

$sql_url  = 'https://sqlite.org'
$sql_pre  = 'sqlite-autoconf-'

#———————————————————————————————————————————————————————————————— make info
Make-Const dest_so  'lib\sqlite3'
Make-Const exts     @( @{ 'conf' = 'ext/sqlite3/extconf.rb' ; 'so' = 'sqlite3_native' } )
Make-Const write_so_require $false

#———————————————————————————————————————————————————————————————— repo changes
function Repo-Changes {
  # zlib build files are normally in MSYS2 installations,
  # but they are not in DevKit
  Package-DevKit 'zlib-1.2.8'
}

#———————————————————————————————————————————————————————————————— pre compile
function Pre-Compile {
  # This function is used to compile SQLite, as defined by variables above.
  # We don't need to compile this for every Ruby version.
  # For 64 bit, all versions (2.0 thru trunk) seemed to work with a MSYS2
  # compiled version.
  # For 32 bit, needed to separately compile for versions <= 2.3 (DevKit), and
  # > 2.3 (RI2 / MSYS2).

  $new_path = "$dir_gem\tmp\$r_arch\ports"
  
  # only compile first RI2 if 64 bit
  if ( (!$is64 -And $ruby -eq '23') -Or $ruby -eq $rubies[0] ){
    Write-Host "Compiling SQLite..." -ForegroundColor $fc
    $fn = "$sql_pre$sql_vers.tar.gz"
    $fp = "$pkgs\$fn"
    if( !(Test-Path -Path $fp -PathType Leaf) ) {
      $wc.DownloadFile("$sql_url/$sql_year/$fn", $fp)
    }
    $t = "-o$pkgs"
    &$7z e -y $fp $t 1> $null
    $fp = $fp -replace "\.gz\z", ""
    &$7z x -y $fp $t 1> $null

    if (Test-Path -Path $new_path -PathType Container) {
      Remove-Item -Path $new_path -Recurse -Force
    }
    New-Item -Path $new_path -ItemType Directory 1> $null
    
    # Move SQLite contents to $new_path
    Get-ChildItem -Path "$pkgs\$sql_pre$sql_vers" -Recurse |
      Move-Item  -force -destination $new_path

    Push-Location $new_path
    if ($is64) {
      bash Configure CFLAGS="-O2 -DSQLITE_ENABLE_COLUMN_METADATA -fPIC" --disable-shared
      make -j2
    } else {
      bash Configure CFLAGS="-O2 -DSQLITE_ENABLE_COLUMN_METADATA" --disable-shared
      make
    }
    Pop-Location
  }
  $t = $new_path.replace('\', '/')
  $env:b_config = " --with-sqlite3-dir=$t --with-opt-include=$t --with-sqlite3-lib=$t/.libs"
}

#———————————————————————————————————————————————————————————————— Run-Tests
function Run-Tests {
  Update-Gems minitest, rake
  rake -f Rakefile_wintest -N -R norakelib | Set-Content -Path $log_name -PassThru -Encoding UTF8
  # add info after test results
  $(ruby -rsqlite3 -e "STDOUT.write $/ + 'SQLite3::SQLITE_VERSION ' ; puts SQLite3::SQLITE_VERSION") |
    Add-Content -Path $log_name -PassThru -Encoding UTF8
  minitest
}

#———————————————————————————————————————————————————————————————— below for all repos
# below is required code
Make-Const dir_gem  $(Convert-Path $PSScriptRoot\..)
Make-Const dir_ps   $PSScriptRoot

Push-Location $PSScriptRoot
.\shared\make.ps1
.\shared\test.ps1
Pop-Location

exit $ttl_errors_fails + $exit_code
