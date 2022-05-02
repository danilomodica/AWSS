FROM ubuntu:latest
WORKDIR /app
COPY ./data ./
ENV DEBIAN_FRONTEND noninteractive
# ENV FLASK_APP webServer
# ENV FLASK_RUN_HOST 127.0.0.1
RUN apt update && \
    apt -y install gcc mono-mcs python3 pip && \
    rm -rf /var/lib/apt/lists/*
# RUN pip install flask
RUN gcc -O2 -fopenmp ./lcs_algorithm.c -o ./lcs.exe
RUN pip install boto3
RUN pip install awscli
RUN pip install requests
RUN pip install python-decouple
EXPOSE 5000
# CMD ["python3", "-m", "flask", "run","-h","0.0.0.0","-p","5000"]
CMD ["python3", "run.py"]

