# Script to Compile Zimbra FOSS by Version
* A wiki article can be found here: https://wiki.zimbra.com/wiki/JDunphy-CompileZimbraScript.
<p>
 **** Zimbra employedd Yogesh Dasi recently deleted the above wiki article. Why? no reason was given. ****
<pre>
The Zimbra :: Tech Center page JDunphy-CompileZimbraScript has been
deleted on 8 September 2025 by Yogesh.dasi, see
http://wiki.zimbra.com/wiki/JDunphy-CompileZimbraScript.    
</pre>

A single bash script that will build a zimbra release based on the version (AKA: git tag) in contrast to what is actively being worked on in the development tree which may or may not be in a consistent state at the time of the build. It attempts to match NETWORK versions for FOSS version builds.

The script will install the development environment on any of the supported platforms and allow one to build a zimbra release for Version 8.8.15, 9, and 10. It can be found here: [build_zimbra.sh](https://raw.githubusercontent.com/JimDunphy/build_zimbra.sh/master/build_zimbra.sh). To use this script, you must have previously set up your GitHub account (free) and imported your SSH keys to be able to git clone the repositories and have zm-build/build.pl work. If unsure, see this [link](https://github.com/ianw1974/zimbra-build-scripts) as Ian's script will be installing the dependencies. The script uses this repository from Ian.

* [https://github.com/ianw1974/zimbra-build-scripts](https://github.com/ianw1974/zimbra-build-scripts)

This script can build any version and release in 10.1 ,10.0, 9.0, and 8.8.15 FOSS zimbra and will create a tarball when completed. 

* You will extract the tarball and issue `install.sh` - See [zimbra wiki documentation](https://wiki.zimbra.com/wiki/Zimbra_Releases/8.7.0/Single_Server_Installation)
* During the above installation, third party components are supplied by pre-built zimbra repositories (nginx, ldap, etc).

**Note**: If you use this script and a new patch is released, you repeat the build to obtain that release. The Zimbra supplied install.sh in the tarball is smart enough to handle updates vs new installs.

## Step 1 (one time only)

Install the development environment for any supported Zimbra platforms. This will prompt for root via sudo to allow all software and build components to be installed.

```sh
% ./build_zimbra.sh --init
```

## Step 2

Build the latest version using the --version option 

```sh
% ./build_zimbra.sh --version 10.0
```

or Build a specific release.

```sh
% ./build_zimbra.sh --version 10.0.7
```

## Tags

When Zimbra creates releases, they will tag it. Issue any of the following commands to see the tags for your release but this step is no longer necessary as
the script will generate the correct tags on the fly dynamically as the process has been sped up and only takes about 10 seconds to go through 54+ repositories marking the highest tag for each repository in your version build. While not necessary, you can see the tags it is may use by running any of the following --tag commands for the version you want to build.

```sh
% ./build_zimbra.sh --tags 10.1
% ./build_zimbra.sh --tags 10.0
% ./build_zimbra.sh --tags 9.0
% ./build_zimbra.sh --tags 8.8.15
% ./build_zimbra.sh --tags    # Create all files
% ls tags*
% tags_for_10_0.txt  tags_for_10_1.txt  tags_for_8_8_15.txt  tags_for_9_0.txt
% cat tags_for_10.txt 
10.0.8,10.0.7,10.0.6,10.0.5,10.0.4,10.0.2,10.0.1,10.0.0-GA,10.0.0
```

## Building New Patch Releases 

Your current directory contains a previous build for Zimbra 10.0.7. You can verify this by running any of the commands below:

```sh
% ./build_zimbra.sh --version 10.0.7 --dry-run
% tail -1 builds.log
% ls -lt BUILDS
```

A new patch 10.0.8 was announced and you now want to build this latest patch release.

```sh
% ./build_zimbra.sh --version 10.0.8 
```

**Note**: It can take [Zimbra up to a week](https://forums.zimbra.org/viewtopic.php?p=313525#p313525) to push all their new patches to the FOSS GitHub after they announce a new NETWORK release. Using the `./build_zimbra.sh --show-tags` will provide a list of repositories, the tag, and date to help determine when.

## How it Works

The [Zimbra build documentation](https://github.com/Zimbra/zm-build) describes doing the following:

```sh
% mkdir installer-build
% cd installer-build
% git clone --depth 1 --branch 10.0.6 git@github.com:Zimbra/zm-build.git
% cd zm-build
% ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag=10.0.8,10.0.7,10.0.6,10.0.5,10.0.4,10.0.3,10.0.2,10.0.1,10.0.0-GA --build-release-no=10.0.8 --build-type=FOSS --build-release=LIBERTY --build-release-candidate=GA --build-thirdparty-server=files.zimbra.com --no-interactive
```

There are 2 parts to this complex command line:

* Determine which branch to clone for zm-build.
* The tags to use and supply with the `--git-default-tag` option.

This script iterates through the GitHub repository and builds the tags for the zimbra version you want to build. It then takes the version you are attempting to build and find the highest branch for zm-build to checkout. Using the `--dry-run` option, you can see what it has determined and compare.

## Useful Commands

```sh
```
% ./build_zimbra.sh --help

        ./build_zimbra.sh
        --init                     #first time to setup envioroment (only once)
        --version [10.1|10.0|9.0|8.8.15]         #build release 8.8.15 or 9.0.0 or 10.0.0
        --version 10.0.8           #build release 10.0.8
        --debug                    #extra output - use as 1st argument
        --clean                    #remove everything but BUILDS
        --tags [10.0]              #create tag files. If version is absent, generate all known tag file versions
        --upgrade                  #echo what needs to be done to upgrade the script
        --builder foss             # an alphanumeric builder name, updates .build.builder file with value
        --builderID [\d\d\d]       # 3 digit value starting at 101-999, updates .build.number file with value
        -V                         #version of this program
        --dry-run                  #show what we would do
        --show-tags                #show latest tag for each repositories
        --show-tags | grep 10.0.8  #show latest tag for each repositories with 10.0.8
        --show-cloned-tags         #show tag of each cloned repository used for build
        --pimbra                   #Replace Zimbra repository with Patched Repository from PIMBRA Repository when present
        --help

       Example usage:
       ./build_zimbra.sh --init               # first time only
       ./build_zimbra.sh --upgrade            # show how get latest version of this script
       ./build_zimbra.sh --upgrade | sh       # overwrite current version of script with latest version from github
       ./build_zimbra.sh --version 10.0       # build latest patch version 10.0 according to tags
       ./build_zimbra.sh --version 10.1       # build latest patch version 10.1 according to tags
       ./build_zimbra.sh --version 10.0.6     # build version 10.0.6
       ./build_zimbra.sh --version 10.1.0     # build version 10.1.0

       ./build_zimbra.sh --version 9.0     #build version 9 
       ./build_zimbra.sh --version 8.8.15  #build version 8 
       ./build_zimbra.sh --version 10.0.9 --dry-run  #see how to build version 10.0.9
       ./build_zimbra.sh --version 10.0.8  #build version 10.0.8
       ./build_zimbra.sh --version 10.1.1  #build version 10.1.1
       ./build_zimbra.sh --dry-run --version 9.0 --pimbra   # build version 9.0 with PIMBRA repositories 

      Note: ********************************************************************************
        The latest tags are dynmically generated before each build specific to the version specified
        A --clean is issued if a previous build was found. The only time this does not happen is if the --debug flag is issued.

      *****************************************************************************************



See how it will build the latest version of 10.0: (Note: you could use `--version 10.0.7` if you know the patch you want)

```sh
% ./build_zimbra.sh --version 10.0 --dry-run
#!/bin/sh
git clone --depth 1 --branch "10.0.6" "git@github.com:Zimbra/zm-build.git"
cd zm-build
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="10.0.7,10.0.6,10.0.5,10.0.4,10.0.2,10.0.1,10.0.0-GA,10.0.0" --build-release-no="10.0.7" --build-type=FOSS --build-release="DAFFODIL" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=GA
```

Now build version 10.0 patch 7 shown above:

```sh
% ./build_zimbra.sh --version 10.0.7
...
...
...sudo bash -s <<"EOM_SCRIPT"
[ -f /etc/redhat-release ] && ( yum install -y epel-release && yum install -y nginx && service nginx start )
[ -f /etc/redhat-release ] || ( apt-get -y install nginx && service nginx start )
tee /etc/nginx/conf.d/zimbra-pkg-archives-host.conf <<EOM
server {
  listen 8008;
  location / {
     root /home/jad/build-zimbra/zmbuild/my-automated-build/BUILDS;
     autoindex on;
  }
}
EOM
service httpd stop 2>/dev/null
service nginx restart
service nginx status
EOM_SCRIPT


=========================================================================================================

BUILDS/RHEL8_64-DAFFODIL-1007-20240319140057-FOSS-1000/zcs-10.0.7_GA_1000.RHEL8_64.20240319140057.tgz
BUILDS/RHEL8_64-KEPLER-900-20240319113455-FOSS-1000/zcs-9.0.0_GA_P39_1000.RHEL8_64.20240319113455.tgz
BUILDS/RHEL8_64-JOULE-8815-20240319111605-FOSS-1000/zcs-8.8.15_GA_P46_1000.RHEL8_64.20240319111605.tgz
```

See what it takes to build Zimbra version 8:

```sh
% ./build_zimbra.sh --version 8.8.15 --dry-run
#!/bin/sh
git clone --depth 1 --branch "8.8.15.p45" "git@github.com:Zimbra/zm-build.git"
cd zm-build
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="8.8.15.p46,8.8.15.p45,8.8.15.p44,8.8.15.p43,8.8.15.p41,8.8.15.p40,8.8.15.P40,8.8.15.p39.1,8.8.15.p39,8.8.15.p37,8.8.15.p36,8.8.15.p35,8.8.15.p34,8.8.15.p33,8.8.15.p32,8.8.15.p31.1,8.8.15.p31,8.8.15.p30,8.8.15.p29,8.8.15.p28,8.8.15.p27,8.8.15.p26,8.8.15.p25,8.8.15.p24,8.8.15.p17,8.8.15.p23,8.8.15.p22,8.8.15.p21,8.8.15.p20,8.8.15.p19,8.8.15.p18,8.8.15.p15.nysa,8.8.15.p16,8.8.15.p15,8.8.15.p14,8.8.15.p13,8.8.15.p12,8.8.15.p11,8.8.15.p10,8.8.15.p9,8.8.15.p8,8.8.15.p7,8.8.15.p6.1,8.8.15.p6,8.8.15.p5,8.8.15.p4,8.8.15.p3,8.8.15.p2,8.8.15.p1,8.8.15.0,8.8.15" --build-release-no="8.8.15" --build-type=FOSS --build-release="JOULE" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=GA_P46
```

Now Version 9.

```sh
% ./build_zimbra.sh --version 9.0 --dry-run
#!/bin/sh
git clone --depth 1 --branch "9.0.0.p38" "git@github.com:Zimbra/zm-build.git"
cd zm-build
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="9.0.0.p39,9.0.0.p38,9.0.0.p37,9.0.0.p36,9.0.0.p34,9.0.0.p33,9.0.0.P33,9.0.0.p32.1,9.0.0.p32,9.0.0.p30,9.0.0.p29,9.0.0.p28,9.0.0.p27,9.0.0.p26,9.0.0.p25,9.0.0.p24.1,9.0.0.p24,9.0.0.p23,9.0.0.p22,9.0.0.p21,9.0.0.p20,9.0.0.p19,9.0.0.p18,9.0.0.p17,9.0.0.p16,9.0.0.p15,9.0.0.p14,9.0.0.p13,9.0.0.p12,9.0.0.p11,9.0.0.p10,9.0.0.p9,9.0.0.p8,9.0.0.p7,9.0.0.p6,9.0.0.p5,9.0.0.p4,9.0.0.p3,9.0.0.p2,9.0.0.p1,9.0.0" --build-release-no="9.0.0" --build-type=FOSS --build-release="KEPLER" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=GA_P39
```

Show latest tags in repositories

```sh
% ./build_zimbra.sh --show-tags | head -10
Tag Name             Formatted Date                 Directory           
10.0.5               2023-09-20 07:30:53            zm-admin-ajax       
10.0.8               2024-04-11 23:38:04            zm-admin-console    
10.1.0.beta          2024-04-08 11:21:32            zm-admin-help-common
10.0.5               2023-09-20 07:51:32            zm-ajax             
10.0.1               2023-05-17 02:06:44            zm-amavis           
10.0.8               2024-04-12 01:09:56            zm-aspell           
10.0.6               2023-11-29 02:25:48            zm-build            
10.0.0-GA            2023-03-08 21:06:59            zm-bulkprovision-admin-zimlet
10.0.0-GA            2023-03-08 21:07:22            zm-bulkprovision-store
```

Show tags used to clone the repositories for the current build

```sh
% ./build_zimbra.sh --show-cloned-tags | head -10
Tag Name             Formatted Date                 Directory           
10.0.5               2023-09-20 07:30:53            zm-admin-ajax       
10.0.8               2024-04-11 23:38:04            zm-admin-console    
10.0.0-GA            2023-03-08 21:00:27            zm-admin-help-common
10.0.5               2023-09-20 07:51:32            zm-ajax             
10.0.1               2023-05-17 02:06:44            zm-amavis           
10.0.8               2024-04-12 01:09:56            zm-aspell           
10.0.6               2023-11-29 02:25:48            zm-build            
10.0.0-GA            2023-03-08 21:06:59            zm-bulkprovision-admin-zimlet
10.0.0-GA            2023-03-08 21:07:22            zm-bulkprovision-store
```

## Universal Naming

This script will attempt to label the builds and document how the build was created. It will encode the tags used in the build what branch that zm-build.git was checked out to do the build. An example:

```sh
% ls -lt BUILDS/
drwxr-xr-x 3 jad jad 4096 Apr 22 09:29 RHEL8_64-DAFFODIL_T100008C100006FOSS-1008-20240422091945-FOSS-1131007
drwxr-xr-x 3 jad jad 4096 Apr 22 06:24 RHEL8_64-DAFFODIL_T100007C100006JAD-1007-20240422061457-FOSS-1131006
drwxr-xr-x 3 jad jad 4096 Apr 22 06:08 RHEL8_64-DAFFODIL_T100008C100006FOSS-1008-20240422055830-FOSS-1131005
drwxr-xr-x 3 jad jad 4096 Apr 21 07:55 RHEL8_64-KEPLER_T090000p39C090000p38JIM-900-20240421074316-FOSS-1131004
drwxr-xr-x 3 jad jad 4096 Apr 21 07:32 RHEL8_64-JOULE_T080815p46C080815p45JAD-8815-20240421071950-FOSS-1031003
drwxr-xr-x 3 jad jad 4096 Apr 21 07:05 RHEL8_64-DAFFODIL_T100008C100006FOSS-1008-20240421065519-FOSS-1011001
```

Any build in a new directory will have the default builder name of FOSS and a starting build number of 1011001 where 101 represents the builderID part encoded in the build number unless overridden with `--builder` or `--builderID`. Subsequent builds will be 1011002, etc, etc. The build number is passed through to the web client as a result.

For example:

```sh
RHEL8_64-DAFFODIL_T100008C100006FOSS-1008-20240421065519-FOSS-1011001
```

contains a few bits of information. Here is what we know from T100008C100006FOSS:

* built for RHEL8_64 and had tags T100008 - tags 10.0.8
* Further it was built from clone branch of zm-build of 10.0.6
* 101 is the builder id and the script or entity that built it.
* 1001 is the build number and is incremented automatically by build.pl
* builder name is FOSS which represents how/who built it

Here is how the build was previously created:

```sh
% ./build_zimbra.sh --version 10.0.8 --dry-run
#!/bin/sh
git clone --depth 1 --branch "10.0.6" "git@github.com:Zimbra/zm-build.git"
cd zm-build
ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag="10.0.8,10.0.7,10.0.6,10.0.5,10.0.4,10.0.2,10.0.1,10.0.0-GA,10.0.0" --build-release-no="10.0.8" --build-type=FOSS --build-release="DAFFODIL_T100008C100006FOSS" --build-thirdparty-server=files.zimbra.com --no-interactive --build-release-candidate=GA
```

To brand the build and create a new build, you can do this:

```sh
% ./build_zimbra.sh --version 10.0.7 --builder JAD
```

And the FOSS will be removed and replaced with JAD. The encoding is still FOSS-1011006

```sh
drwxr-xr-x 3 jad jad 4096 Apr 22 06:24 RHEL8_64-DAFFODIL_T100007C100006JAD-1007-20240422061457-FOSS-1011006
```

Ref: [https://forums.zimbra.org/viewtopic.php?p=313466#p313466](https://forums.zimbra.org/viewtopic.php?p=313466#p313466)

## Important Files

The script maintains 3 state files and they are created automatically. You can changed the contents with:

* .build.number --- changed with --builderID. Used by build.pl which increments the build number.
* .build.builder --- changed with --builder 
* builds.logs

```sh
% cat builds.log
0240420-162530  4311006  RHEL8_64-DAFFODIL_T100007C100006FOSS-1007-20240420161606-FOSS-4311006
20240421-070503  1011001  RHEL8_64-DAFFODIL_T100008C100006FOSS-1008-20240421065519-FOSS-1011001
20240421-073241  1031003  RHEL8_64-JOULE_T080815p46C080815p45JAD-8815-20240421071950-FOSS-1031003
20240421-075503  1131004  RHEL8_64-KEPLER_T090000p39C090000p38JIM-900-20240421074316-FOSS-1131004
20240422-060824  1131005  RHEL8_64-DAFFODIL_T100008C100006FOSS-1008-20240422055830-FOSS-1131005
20240422-062417  1131006  RHEL8_64-DAFFODIL_T100007C100006JAD-1007-20240422061457-FOSS-1131006
20240422-092928  1131007  RHEL8_64-DAFFODIL_T100008C100006FOSS-1008-20240422091945-FOSS-1131007
```

## Limitations

This script attempts to build its releases based on the available tags at the time of compile. It will walk through attempting to guess at the tags used as Zimbra NETWORK builds are not based on the public git tree that we have access to. If you need a specific version built then specify it on the command line.

Example: `--version 10.0.5` instead of `--version 10`  (which would be 10.0.7 as this is written)

# FOSS Builds and Projects

* [https://github.com/Zimbra/zm-build](https://github.com/Zimbra/zm-build) - Documentation how to build from Zimbra
* [https://github.com/ianw1974/zimbra-build-scripts](https://github.com/ianw1974/zimbra-build-scripts) - All platforms and binaries every quarter
* [https://github.com/maldua/zimbra-foss-builder/](https://github.com/maldua/zimbra-foss-builder/) - All platforms for 10,9,8 [binaries](https://maldua.github.io/zimbra-foss-builder/downloads.html) every release
* [https://drive.janskolnik.net/s/cyjYjzkHT9nqGgQ](https://drive.janskolnik.net/s/cyjYjzkHT9nqGgQ) - RHEL 8 & Ubuntu 20.04 by Jan Skolnik ([telegraph support channel](https://t.me/zimbra_community))
* [https://zintalio.com/release-notes10.html](https://zintalio.com/release-notes10.html) - ubuntu only with repository for updates
* [https://github.com/GriffinPlus/docker-zimbra](https://github.com/GriffinPlus/docker-zimbra) - docker w/ 8.8.15GA
* [https://forums.zimbra.org/viewtopic.php?p=312924#p312924](https://forums.zimbra.org/viewtopic.php?p=312924#p312924) - moving from Dev branch builds to FOSS tag builds
* [https://zcsplus.com/](https://zcsplus.com/) - Ubuntu 20.04 LTS (hybrid of Zimbra 10 + Zextras Suite, etc)

More articles written by me, [JDunphy-Notes](https://wiki.zimbra.com/wiki/JDunphy-Notes)

