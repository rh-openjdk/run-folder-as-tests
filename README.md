# run-folder-as-tests

ancient dummy suite which can run folder with shell scripts as testsuite and  publish junit/xunit compatible resultfile

A typical folder looks like:
```
containersQa/
├── 001_prepareDocker.sh
├── 002_aPodmanVersion.sh
├── 002_baseImage.sh
├── 003_hostInfo.sh
...
├── 221_runS2iLocaDeps.sh
├── 222_checkS2iLocaMultiModWorksNoMain.sh
├── 223_runS2iLocaMultiModWorksMain.sh
├── 224_runS2iLocaDepsNoInstall.sh
├── 410_s2iLocaBasic.sh
├── 420_runS2iLocaBasic.sh
├── 600_newUserCheck.sh
├── HelloWorld.java
├── jenkins_settings.xml
├── readme
└── testlib.bash
```
Next to junit/jtreg compatible outpu it supports `ignoring` of tests and reruning of failures. Only .sh files are run. 

```
.../run-folder-as-tests/run-folder-as-tests.sh .../containersQa tested_product
```

Output from above run would be folder with individual details folders:
```
001_prepareDocker.sh-result
002_aPodmanVersion.sh-result
..
221_runS2iLocaDeps.sh-result
222_checkS2iLocaMultiModWorksNoMain.sh-result
223_runS2iLocaMultiModWorksMain.sh-result
224_runS2iLocaDepsNoInstall.sh-result
410_s2iLocaBasic.sh-result
420_runS2iLocaBasic.sh-result
600_newUserCheck.sh-result
rpms_metadata
containerQa.properties
containersQa.jtr.xml
containersQa.tar.gz
results.properties
results.txt
```
and summed up  `results.properties`  and  junit result file `containersQa.jtr.xml` eith its packed varriant in tar.gz - up to you wchich t keep. Directly connectable with:
 * https://github.com/judovana/jenkins-report-jck/
 * https://github.com/judovana/jenkins-report-generic-chart-column
 * https://plugins.jenkins.io/junit/


`jtreg-shell-xml.sh` can be used as standlone, if you need to generate trivial junit file from bash.
`tap-shell-tap.sh` can be used as standlone, if you need to generate trivial tap file from bash.
