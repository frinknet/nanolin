# package system

NOTE: The Nanolin Package System is a work in progress like everything else.

Nanolin has multiple packaging systems which can be confusingat first glance.
However, the whole point of **packages**, **repos**, **distros**, **releases**
and **remotes**, is to allow for almost any release strategy from rolling
releases to fully managed upgrades.

## packages

Packages are defined in severa ways. First there is the **.rcp** file which is
a recipe for the package. Then there is the **.lst** file which contains a list
of all installed installed files. Then there is the **.img** file which contains
a compiled binary package, And finally there is a  **.sig** file for signing the
binary distribution package. This allows both binary and source distributions.

## repos

A repository is always served by anything that provies a directory allowing for
both local and repositories. The repository minimally provides a **packages.tgz**
file containing a full list of **.rcp** file and also a** manifest.tgz** which
contains a set of **.lst** files. If the repo will be serving binary files it
will aslo contain a **signature.pub** file which signs all binary packages.

The binary packages are appended with a release format (r19.02-G22132245) based
on UTC date of generation. This allows several version to be hosted by the
repository. Allowing for hosting earlier versions. 
 
## distros

Packages can be grouped together into distros. Distros are defined using the same
**.rcp** syntax allowing to easily create your custom distribution based on 
other generations with little effort. Distros have **.img** files lust like
packages. They alway us release versioning to allow semantic versioning and easy
automatic upgrades. In fact, the primary purpose of distros is to allow for
automatic updates with easy roleback capabilities.

## releases

A release is any publically hosted binary distro that is turned into an **.iso**
image. The format is flexible to allow for both live booting and quick install of
a distro to any system. The releases can be preconfigure to require registration
upon bootup so that user access can be managed remotely.

# remotes

Remotes are used for automatic upgrades and optional centralized user management.
Seting up a remote is simple allowing anyone to have a specialized OS taylored to
their specific application.

# overlays

Buth package and releases can be used to create file system overlays allowing for
dynamic use cases and secure multipurpose systems. This allows for parts of the
system to be turned on and off dynamically. 
