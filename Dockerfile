FROM ubuntu:latest
WORKDIR /app
COPY ./webserver ./
ENV DEBIAN_FRONTEND noninteractive
ENV FLASK_APP webServer.py
ENV FLASK_RUN_HOST 127.0.0.1
RUN apt update && \
    apt -y install gcc mono-mcs python3 pip && \
    rm -rf /var/lib/apt/lists/*
RUN pip install flask
RUN gcc -O2 -fopenmp ./exe/lcs.c -o ./exe/Substring
CMD ["python3", "-m", "flask", "run","-h","0.0.0.0","-p","5000"]
