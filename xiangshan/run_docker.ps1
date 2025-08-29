docker run --rm -it `
    -v ${PWD}:/home/builder/workspace `
    -v ${PWD}/NEMU:/opt/NEMU `
    -v ${PWD}/nexus-am:/opt/nexus-am `
    -e NOOP_HOME=/home/builder/workspace/xiangshan `
    -e NEMU_HOME=/opt/NEMU `
    -e AM_HOME=/opt/nexus-am `
    scala-dev-env bash
