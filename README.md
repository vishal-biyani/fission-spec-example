# fission-spec-example

## Building source code locally

This example will showcase how to use specs in Fission so that CI/CD flow can be designed better using the specs. Also we are building the function as part of this flow - so it is assumed that the Kubernetes cluster does not have internet connectivity and can not run things like `pip` or `maven` to fetch dependencies for building from source to package.

We have a simple python function which needs one library for it's working. The files are:

```
$ tree .
.
├── __init__.py
├── requirements.txt
└── user.py

0 directories, 4 files
```

The user.py is a simple function which uses yaml library and dumps a simple document:

```
$ cat user.py 
import sys
import yaml

document = """
  a: 1
  b:
    c: 3
    d: 4
"""

def main():
    return yaml.dump(yaml.load(document))
```
In the requirements file we declare the `pyyaml` library that we need

```
$ cat requirements.txt 
pyyaml
```

Finally - we want to build the source code locally so that all dependencies of the function are packed with function. For this you can run `pip install` in a way that dependencies are placed in same directory or you can use a simple helper script below which uses a docker container to build it. The docker container is useful if the machine on which you build source code does not have pip installed.

```
$ cat build.sh 
#/bin/bash
# A script which builds the source code using pip and a docker container so that you don't need Pip on host machine
#
docker run -it --rm -v$(pwd):/app chauffer/pip3-compile pip install -r requirements.txt -t /app
```

When we run above script, we can see that the yaml module is downloaded.

```
$ ./build.sh
Collecting pyyaml (from -r requirements.txt (line 1))
  Downloading https://files.pythonhosted.org/packages/9e/a3/1d13970c3f36777c583f136c136f804d70f500168edc1edea6daa7200769/PyYAML-3.13.tar.gz (270kB)
    100% |████████████████████████████████| 276kB 215kB/s 
Building wheels for collected packages: pyyaml
  Running setup.py bdist_wheel for pyyaml ... done
  Stored in directory: /root/.cache/pip/wheels/ad/da/0c/74eb680767247273e2cf2723482cb9c924fe70af57c334513f
Successfully built pyyaml
Installing collected packages: pyyaml
Successfully installed pyyaml-3.13

```

You can also confirm that the yaml module is downloaded in same directory as source code - now the function and it's dependencies are all in same directory.

```
$ tree -L 1
.
├── PyYAML-3.13.dist-info
├── __init__.py
├── _yaml.cpython-37m-x86_64-linux-gnu.so
├── build.sh
├── requirements.txt
├── user.py
└── yaml

2 directories, 5 files
```

## Using Fission Specs

Now let's use spec to create environment and function and deploy to a cluster. The first step is to initialize the fission spec - so that it creates a spec directory and stores all specs in that directory.

```
$ fission spec init
Creating fission spec directory 'specs'
```

Next is to create environment spec - this does not actually create environment since we are using the `--spec` flag. If you look at the environment spec file, it's like a Kubernetes YAML definition. 

```
$ fission env create --name python --image fission/python-env --spec

$ cat specs/env-python.yaml 
apiVersion: fission.io/v1
kind: Environment
metadata:
  creationTimestamp: null
  name: python
  namespace: default
spec:
  TerminationGracePeriod: 360
  builder: {}
  keeparchive: false
  poolsize: 3
  resources: {}
  runtime:
    functionendpointport: 0
    image: fission/python-env
    loadendpointpath: ""
    loadendpointport: 0
  version: 1
```
Next, let's create the function specs. This will also create the package spec inside the function file.

```
$ fission fn create --name pyfunc --env python --executortype newdeploy --minscale 1 --deploy "*" --entrypoint user.main --spec
$ cat specs/function-pyfunc.yaml 
include:
- '*'
kind: ArchiveUploadSpec
name: default-kxFr

---
apiVersion: fission.io/v1
kind: Package
metadata:
  creationTimestamp: null
  name: dfxr
  namespace: default
spec:
  deployment:
    checksum: {}
    type: url
    url: archive://default-kxFr
  environment:
    name: python
    namespace: default
  source:
    checksum: {}
status:
  buildstatus: none

---
apiVersion: fission.io/v1
kind: Function
metadata:
  creationTimestamp: null
  name: pyfunc
  namespace: default
spec:
  InvokeStrategy:
    ExecutionStrategy:
      ExecutorType: newdeploy
      MaxScale: 1
      MinScale: 1
      TargetCPUPercent: 80
    StrategyType: execution
  configmaps: null
  environment:
    name: python
    namespace: default
  package:
    functionName: user.main
    packageref:
      name: dfxr
      namespace: default
  resources: {}
  secrets: null
```

Now next step is to validate the specs and apply them. In a typical CI/CD workflow, the developer will create specs and commit them to Git. The CI/CD system will only validate and apply specs. The apply command makes sure that the changes only are applied to the cluster.


```
$ fission spec validate
$ fission spec apply
uploading archive archive://default-kxFr
1 environment created: python
1 package created: dfxr
1 function created: pyfunc
```

Now is the time to quickly check if the function works:

```
$ fission fn test --name pyfunc
a: 1
b: {c: 3, d: 4}
```

After you are done, you can use destroy command to delete all related objects - and you don't need to individually delete one object at a time:

```
$ fission spec destroy
Deleted Environment default/python
Deleted Package default/dfxr
Deleted Function default/pyfunc
```

## Specs on steroids

The specs allow you do additional things. The `spec.runtime.container` is basically the container spec from Kubernetes. This allows you add environment variables to Functions as shown below. In future Fission might support `PodSpec` - which will allow to do more things in future.

```
apiVersion: fission.io/v1
kind: Environment
metadata:
  creationTimestamp: null
  name: jvm
  namespace: default
spec:
  TerminationGracePeriod: 360
  builder: {}
  keeparchive: true
  poolsize: 3
  resources: {}
  runtime:
    functionendpointport: 0
    image: fission/jvm-env
    loadendpointpath: ""
    loadendpointport: 0
    container:
      env:
      - name: JVM_OPTS
        value: "-Xms256M -Xmx1024M"
  version: 2
```

