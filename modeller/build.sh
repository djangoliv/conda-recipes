#!/bin/bash

modtop=${PREFIX}/lib/${PKG_NAME}-${PKG_VERSION}

if [ `uname -s` = "Darwin" ]; then
  tar -xzf *.pax.gz
  mkdir -p ${PREFIX}/lib
  # Fix broken HDF5 symlinks in 9.15 package (fixed in SVN)
  (cd Library/modeller-*/lib/mac10v4 && rm -f libhdf5.dylib libhdf5_hl.dylib && ln -sf libhdf5.8.dylib libhdf5.dylib && ln -sf libhdf5_hl.8.dylib libhdf5_hl.dylib)

  # Move from .dmg location to Anaconda path
  mv Library/modeller* ${PREFIX}/lib

  # Note that we keep the glib that is already bundled with Modeller, since
  # it is newer than that in Anaconda

  # Change library paths accordingly
  exetype="mac10v4-intel64"
  univ_exetype="mac10v4"
  libs="ifcore imf irc svml intlc glib-2.0.0 intl.8 hdf5.8 hdf5_hl.8 saxs modeller.10"
  for lib in ${libs}; do
    install_name_tool -id ${modtop}/lib/${univ_exetype}/lib${lib}.dylib \
                          ${modtop}/lib/${univ_exetype}/lib${lib}.dylib
  done
  for bin in ${modtop}/bin/mod*_* ${modtop}/lib/${univ_exetype}/*.{dylib,so}; do
    for lib in ${libs}; do
      install_name_tool -change /Library/${PKG_NAME}-${PKG_VERSION}/lib/${univ_exetype}/lib${lib}.dylib ${modtop}/lib/${univ_exetype}/lib${lib}.dylib ${bin}
    done
  done

  # Have modXXX find the _modeller.so built against the system Python
  mkdir ${modtop}/syspython
  mv ${modtop}/lib/mac10v4/_modeller.so ${modtop}/syspython
  perl -pi -e "s#^exec#export PYTHONPATH=${modtop}/syspython\\nexec#" ${modtop}/bin/mod${PKG_VERSION}

else
  if [ "${ARCH}" = "64" ]; then
    exetype="x86_64-intel8"
  else
    exetype="i386-intel8"
  fi
  /bin/echo -e "\n${modtop}\nXXXX\n\n\n\n" | ./Install

  # Have modXXX find the _modeller.so built against the bundled Python (2.3)
  mkdir ${modtop}/syspython
  mv ${modtop}/lib/${exetype}/_modeller.so ${modtop}/syspython
  perl -pi -e "s#^exec#export PYTHONPATH=${modtop}/syspython\\nexec#" ${modtop}/bin/mod${PKG_VERSION}

  # Remove other Python versions (we'll build one later on in the script)
  rm -rf ${modtop}/lib/${exetype}/python*.*

  # Don't need modpy.sh
  rm -f ${modtop}/bin/modpy.sh

  # Bundle glib so we don't need it as a runtime dependency (since it pulls in
  # gettext which might interfere with the system copy)
  cp ${PREFIX}/lib/{libintl.so.8,libglib-2.0.so.0} ${modtop}/lib/${exetype}/

  # Remove bundled HDF5; use the conda package instead
  rm -f ${modtop}/lib/${exetype}/*hdf5*

  # To fix upstream: replace libmodeller.so copy with symlink
  rm -f ${modtop}/lib/${exetype}/libmodeller.so
  (cd ${modtop}/lib/${exetype} && ln -sf libmodeller.so.* libmodeller.so)
fi

mv ${modtop}/bin/mod${PKG_VERSION} ${PREFIX}/bin
perl -pi -e "s#^MODINSTALL(.*)=.*#MODINSTALL\$1=/opt/anaconda1anaconda2anaconda3/lib/${PKG_NAME}-${PKG_VERSION}#" ${PREFIX}/bin/mod${PKG_VERSION}

# Put pure Python interface in the standard search paths
ln -s ${modtop}/modlib/modeller ${SP_DIR}

perl -pi -e "s/^exetype =.*$/exetype = \"${exetype}\"/" \
         ${modtop}/src/swig/setup.py

# to fix upstream: setup.py doesn't currently work with Python 3
py_major=`echo ${PY_VER} | cut -b1`
if [ "${py_major}" = "3" ]; then
  perl -pi -e 's/import commands/import subprocess/;' \
           -e 's/for token in.*$/for token in subprocess.check_output(["pkg-config", "--libs", "--cflags"] + list(packages), universal_newlines=True).split():/;' \
           -e 's/^.*join\(packages\).*$//;' \
           ${modtop}/src/swig/setup.py
fi

# Build Python extension from SWIG inputs
cd ${modtop}/src/swig
swig -python -keyword -nodefaultctor -nodefaultdtor -noproxy modeller.i
python setup.py build
cp build/lib.*${PY_VER}/_modeller*.so ${SP_DIR}
rm -rf build modeller_wrap.c

# Make config.py
cat > ${modtop}/modlib/modeller/config.py <<END
install_dir = r'${modtop}'
license = r'XXXX'
END

# Put headers in more usual locations
cd ${modtop}/src/include
mkdir -p ${PREFIX}/include/modeller
mv mod*.h ${exetype}/fortran-pointer-types.h ${PREFIX}/include/modeller/
cd ${modtop}/src
rm -rf include
ln -sf ${PREFIX}/include/modeller include

if [ `uname -s` = "Darwin" ]; then
  # Make Python extension link against glib and intl bundled with Modeller,
  # not from Anaconda
  for lib in glib-2.0.0 intl.8; do
    install_name_tool -change @rpath/./lib${lib}.dylib ${modtop}/lib/${univ_exetype}/lib${lib}.dylib ${SP_DIR}/_modeller*.so
  done

  # Put libraries in more usual locations
  ln -sf ${modtop}/lib/${exetype}/libmodeller.*.dylib ${PREFIX}/lib
  ln -sf ${modtop}/lib/${exetype}/libmodeller.dylib ${PREFIX}/lib
else
  # Put libraries in more usual locations
  ln -sf ${modtop}/lib/${exetype}/libmodeller.so.* ${PREFIX}/lib
  ln -sf ${modtop}/lib/${exetype}/libmodeller.so ${PREFIX}/lib
fi
