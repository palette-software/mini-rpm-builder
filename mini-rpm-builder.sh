#!/bin/bash -e

rpm_spec_template() {
set -e

RPM_NAME=$1
RPM_VERSION=$2
RPM_FILE_SPEC=$3
cat <<-EOF
# Disable the stupid stuff rpm distros include in the build process by default:
#   Disable any prep shell actions. replace them with simply 'true'
%define __spec_prep_post true
%define __spec_prep_pre true
#   Disable any build shell actions. replace them with simply 'true'
%define __spec_build_post true
%define __spec_build_pre true
#   Disable any install shell actions. replace them with simply 'true'
%define __spec_install_post true
%define __spec_install_pre true
#   Disable any clean shell actions. replace them with simply 'true'
%define __spec_clean_post true
%define __spec_clean_pre true
# Disable checking for unpackaged files ?
#%undefine __check_files

# Use md5 file digest method.
# The first macro is the one used in RPM v4.9.1.1
%define _binary_filedigest_algorithm 1
# This is the macro I find on OSX when Homebrew provides rpmbuild (rpm v5.4.14)
%define _build_binary_file_digest_algo 1

# Use bzip2 payload compression
%define _binary_payload w9.bzdio


Name: ${RPM_NAME}
Version: ${RPM_VERSION}
Epoch: 1
Release: 1
BuildArch: noarch
Summary: TODO provide summary
AutoReqProv: no
# Seems specifying BuildRoot is required on older rpmbuild (like on CentOS 5)
# fpm passes '--define buildroot ...' on the commandline, so just reuse that.
BuildRoot: %buildroot
# Add prefix, must not end with /

Prefix: /

Group: default
License: commercial
Vendor: palette-software.net
URL: https://palette-software.net/insight
Packager: Julian <julian@palette-software.com>

%description
Palette Insight Table Loader Tablend Jobs

%prep
# noop

%build
# noop

%install
# noop

%clean
# noop

%files
%defattr(-,root,root,-)

# Reject config files already listed or parent directories, then prefix files
# with "/", then make sure paths with spaces are quoted. I hate rpm so much.
EOF

while IFS='' read -r line || [[ -n "$line" ]]; do
  echo $(echo $line | awk '{print $2}')
done < "$RPM_FILE_SPEC"

cat <<-EOF
%changelog

EOF
}

THIS=$(readlink --canonicalize `dirname $0`)

build_rpm() {
  set -e

  RPM_NAME=$1
  RPM_VERSION=$2
  RPM_SPEC=${RPM_NAME}.spec

  # We'll create this directory inside the RPM_ROOT and copy files here
  # (with their path)

  RPM_FILE_SPEC=$3

  # Create the build root
  BUILD_ROOT=$(mktemp -d /tmp/rpm-builder-root.XXXXXX)
  RPM_OUT_DIR=$THIS/_build

  mkdir -p $RPM_OUT_DIR

  echo "Creating ${BUILD_ROOT}"
  mkdir -p $BUILD_ROOT



  while IFS='' read -r line || [[ -n "$line" ]]; do

    SRC=$(echo $line | awk '{print $1}')
    DST=$(echo $line | awk '{print $2}')
    BUILD_DST=${BUILD_ROOT}${DST}

    # Create the directory of the output file
    mkdir -p `dirname $BUILD_DST`
    # Copy the file
    cp -vR $SRC $BUILD_DST
  done < "$RPM_FILE_SPEC"

  # Create the spec from the template
  rpm_spec_template $RPM_NAME $RPM_VERSION $RPM_FILE_SPEC > $BUILD_ROOT/$RPM_NAME.spec

  echo Building the RPM
  rpmbuild -bb\
    --buildroot "${BUILD_ROOT}"\
    --define "_rpmdir ${RPM_OUT_DIR}"\
    --define "version ${RPM_VERSION}"\
    ${BUILD_ROOT}/$RPM_NAME.spec




  echo "Removing ${BUILD_ROOT}"
  # Clean the build root after the build
  rm -rf $BUILD_ROOT
}


# Check arg count
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <RPM_NAME> <RPM_VERSION> <CONTENTS_LIST_FILE>"
    echo "   RPM_VERSION: the version to set for the RPM file"
    echo "   LOCAL_VERSION: the version to copy from the 'releases' directory"
    echo "   CONTENTS_LIST_FILE: a file containing a line with a pair <SOURCE> <OUTPUT> for each file to include in the output RPM"
    exit 1
fi



build_rpm $1 $2 $3
