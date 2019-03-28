# nanolin
Nanolin Linux Distribution System for Arch

This is very much WIP 

# building

```shell
./nanolin realease build prime
```

# advanced packaging

Nanolin provides both rolling release and distibuted system updates. In addition,
the entire system has been diesigned for remote identity management so that you
can use Nanolin to power appliance like devices that are bundled with remote
services. This feature is optional, but allows for extreme flexibility in creating
a custom purpose specific OS. Packages and distros can be used as dynamic overlays
allowing for nearly instant install and uninstall.

# static core

All core pieces are statically compiled to allow speed and efficiency in operation
as well as security against library linking problems. This also insures that Nanolin
is right at home on embedded devices where dynamic linking may not be available.

# shell scripts init

The Nanolin init is a distributed single stage init system that is easy to grok
with extensiblility at every level allowing any developer to quickly and easily
write custom initializations for their custom distro. This allows for extreme
system tuning that is hard to achieve on any other system.

# concurrent n init scripts

Most of the init process is extreely concurrent allowing faster load times than
almost any other OS. Nanolin was designed from the ground up to allow easy
concurrency in every stage of scripting. This means that we never sacrifice
processing speed fpr ease of use. The simple concurrency model insures maximum
throughput without complicated RPC or messaging busses.

# license compliance built in
Every package automatically generates a license file with a list of rights holders
and an annotated list of licenses referenced in the project. This allows for
complete license compliance providing visibilitie into sources.

# why go big when you can go small?

A core focus is on using small feature limited tools rather than large bloatware
for userspace and system management. Busybox is the only required userspace
installed by default. Signify is used for all cryptographic signature. So the
core system can literally be built as three packages with a bunch of shell scripts.



