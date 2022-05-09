FROM ubuntu:latest
WORKDIR /app
COPY ./data ./
ENV DEBIAN_FRONTEND noninteractive
RUN apt update && \
    apt -y install gcc mono-mcs python3 pip && \
    rm -rf /var/lib/apt/lists/*
RUN gcc -O2 -fopenmp lcs_algorithm.c -o lcs
RUN pip install boto3
CMD ["python3","run.py"]

