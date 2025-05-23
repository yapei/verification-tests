# Cucumber based blackbox testing framework for OpenShift

## Getting started

More info you can find in [Overview document](doc/overview.adoc).

### Create local dev environment in container

```
# you can replace oc418 with expected version you want
podman run --env LANG=en_US.UTF-8  --env LANGUAGE=en_US.UTF-8  --env LC_ALL=en_US.UTF-8 \
	   --user root --shm-size 2g --interactive --tty --rm \
	   --entrypoint bash \
	   --volume "$REPLACE_ME/local/path/to/verification-tests:/verification-tests:z" \
	   --volume "$REPLACE_ME/local/path/to/cucushift:/verification-tests/features/tierN:z" \
	   --volume "$REPLACE_ME/local/path/to/cucushift-internal:/verification-tests/private:z" \
       images.paas.redhat.com/aos-qe-ci/jenkins-agent-rhel8-cucushift-oc418:latest
bash-4.4# cd /verification-tests/
```
Then follow steps in [Test scenario execution](#test-scenario-execution)

### Create local dev environment

1. Install git if not installed already, install ruby 2.7 if not installed
2. git clone git@github.com:openshift/verification-tests.git
3. cd verification-tests
4. tools/install_os_deps.sh # need sudo; you may need to login again to terminal if ruby was installed via rvm during this phase (see below for RVM usage)
5. tools/hack_bundle.rb # normal user
6. Install OKD or OpenShift Container Platform client tools
7. Install the web driver if you desire to run tests which work with the Web UI. See [Web Driver](doc/configuration.adoc)

### Update local dev environment

```
bundle update
```

### Test scenario execution

Check [Configuring a BushSlicer v3 run](doc/configuration.adoc)

This is an example:

```
export BUSHSLICER_DEFAULT_ENVIRONMENT=ocp4
export OPENSHIFT_ENV_OCP4_HOSTS=api.*.openshift.com:lb
export OPENSHIFT_ENV_OCP4_USER_MANAGER_USERS=user1:redhat,user2:redhat
export OPENSHIFT_ENV_OCP4_ADMIN_CREDS_SPEC=file:///home/path-to/kubeconfig
export BUSHSLICER_CONFIG='
global:
  browser: chrome
environments:
  ocp4:
    version: "4.9.0"
    #api_port: 443	# For HA clusters, both 3.x and 4.x
    #api_port: 6443	# For non-HA 4.x clusters
    #api_port: 8443	# For non-HA 3.x clusters
    #web_console_url: https://console-openshift-console.apps.*.openshift.com
'

# execute a whole feature file
bundle exec cucumber features/cli/create.feature
# or execute a single scenario
bundle exec cucumber features/cli/create.feature:5
# or execute the smoke tests
bundle exec cucumber --tags @smoke
```

You can check which environments are defined in [config/config.yaml](config/config.yaml).

You could also use the BUSHSLICER_CONFIG variable to override other
configuration options. Add YAML/JSON into it and it will be merged with
configuration file.

### Debugging failures

If any step fails, you will fall into a `pry` shell where you can investigate what's going on. This behavior depends on Cucumber profile that you enable during execution.

1. running steps using `step 'Step name'`
2. inspecting the `@result` variable
3. calling and methods in World

### Running tests from outside this repository

You can put your private test scenarios under `features/tierN` directory.
It is in [.gitignore](.gitignore) so that you can keep your test scenarios under the same file system tree without git messing them up.

## Contributing

Please submit issues and pull requests to the project. You can discuss and ask questions on [OpenShift mailing list](https://lists.openshift.redhat.com/openshiftmm/listinfo/dev).


### RVM for dependency management

If you are planning on installing dependencies for verification Tests on your system, it is often a good idea to use some kind of Version Manager/Package manager, like RVM.

RVM is analogous to virtualenv in python and it stands for Ruby Version Manager.

You can install RVM and read more abou it on https://rvm.io/

Usually once RVM is installed, you would want to create/install a new `rvm` interpreter using:

```
`rvm install "ruby-2.7.6" && rvm  --create use 2.7.6@verification-tests` which will install Ruby 2.7.6 and create a new interpreter as well as a Gemset.
When we install Ruby 2.7.6, it creates a local directory for your user with Ruby 2.7.6 under `~/.rvm/rubies/ruby-2.7.6`.
Once that is done, the Gemset creation is basically an attempt to have dependencies for various apps under same interpreter `2.7.6`. So in this case,
we are creating Gemset `verification-tests` for this repo dependencies. If you had multiple repos, you would use similar command as above to create a new Gemset under 2.7.6
and give it a name that you can recognize. Then for each respective app you may choose to use different gemset as `rvm use 2.7.6@verification-tests` or `rvm use 2.7.6@my-other-repo-or-app`.

Feel free to read about interpreter and gemset in the Ruby docs or elsewhere on the internet.

Once ruby is installed, interpreter is created and gemset is present and activated, you can run `which ruby` to validate if the correct ruby is used and `ruby -v` to check version.
Following this, you may continue the steps as mentioned above, to run `bundle` commands to install gems listed in Gemfile to your Gemset.

Also if you are wondering what does `bundle` command do, search and read about `ruby bundler` on the internet.
```
