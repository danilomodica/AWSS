FROM ubuntu:latest
WORKDIR /app
COPY ./src ./
ENV DEBIAN_FRONTEND noninteractive
RUN apt update && \
    apt -y install python3 pip && \
    rm -rf /var/lib/apt/lists/*
RUN chmod +x lcs
RUN pip install boto3
CMD ["python3","run.py"]