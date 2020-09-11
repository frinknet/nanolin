# recipe package format

The recipe format is one of the most simple package formats available
in any modern distro. There are only a few keywords and the format is
generally declaritive.

# package definition

When defining a package there are a few directives for easy package
description and definition. These are a few common directives that
everyone will immediately recognize and appreciate  

	PACKAGE
	VERSION
	COMMENT

Like all recipe syntag short declarations are on the same line while
long drawn out dissertations are included in the following lines always
indented with a tab character.

# attribution	

Then we also need to include contact and legal information. We always
keep a link to the upstream bug report system so that true problems get
to the people who care about fixing them.

	LICENSE
	CONTACT
	WEBSITE
	BUGTALK

# dependency graph
Then there are a few housecleaning basics that can really help when you
need to build dependency trees and recommended extensions.

	PROVIDE
	REPLACE
	REQUIRE
	SUGGEST
	TOOLING

# file creation

All files are downloaded to src/pkgname. GETFILE obtains the file from
somewhere. PUTFILE creates a file from the inline contents. PATCHES
allows automatic patching of sourcode. 

	GETFILE
	PUTFILE
	PATCHES 

# build process

The build process is defined in four drectives for creating proper stuff.

	COMPILE
	INSTALL 
	INSPECT
	EXPUNGE

# build data

The build creation lists several things...

	DISTURL
	DISTREL
	DISTGEN
	
# repo system

The packaging system includes several directives.

	PKGREPO 
	PKGDATE 
	PKGSIGN  

# distro system

The distro hase a different style header

	RELEASE
	FLAVOUR
	IMPORTS 


