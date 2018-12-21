#/bin/bash
# A script which builds the source code using pip and a docker container so that you don't need Pip on host machine
#
docker run -it --rm -v$(pwd):/app chauffer/pip3-compile pip install -r requirements.txt -t /app
