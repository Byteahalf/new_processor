docker run --rm -it \
    -v ./:/home/builder/workspace/xiangshan \
    -w /home/builder/workspace/xiangshan \
    scala-sbt-min:11 bash
