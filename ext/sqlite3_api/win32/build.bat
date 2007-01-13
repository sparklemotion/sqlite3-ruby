REM This is not guaranteed to work, ever. It's just a little helper
REM script that I threw together to help me build the win32 version of
REM the library. If someone with more win32-fu than I wants to make
REM something more robust, please feel free! I'd love to include it.
REM -- Jamis Buck

cl /LD /Ie:\WinSDK\Include /Ic:\ruby\lib\ruby\1.8\i386-mswin32 /Ic:\ruby\sqlite3\src /Ic:\ruby\src\ruby-1.8.4_2006-04-14 sqlite3_api_wrap.c /link /LIBPATH:c:\ruby\sqlite3 /LIBPATH:e:\WinSDK\Lib /LIBPATH:c:\ruby\lib sqlite3.lib msvcrt-ruby18.lib
