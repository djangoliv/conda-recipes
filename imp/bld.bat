::# Find packages in Anaconda locations
set CMAKE_PREFIX_PATH=%LIBRARY%

:: Fix cmake paths to use / rather than \
patch -p1 < %RECIPE_DIR%\cmake-path.patch
if errorlevel 1 exit 1

mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DIMP_DISABLED_MODULES=scratch -DCMAKE_INSTALL_PREFIX="%LIBRARY%" -DCMAKE_INSTALL_PYTHONDIR="%SP_DIR%" -G "NMake Makefiles" ..
if errorlevel 1 exit 1
nmake
if errorlevel 1 exit 1
nmake install

if errorlevel 1 exit 1

:: Add more build steps here, if they are necessary.

:: See
:: http://docs.continuum.io/conda/build.html
:: for a list of environment variables that are set during the build process.
