FROM python:3-alpine
WORKDIR /app
COPY ./data ./
ENV DEBIAN_FRONTEND noninteractive
RUN apk update && \
    apk add --no-cache gcc libc-dev
RUN gcc -O2 -fopenmp ./lcs_algorithm.c -o ./lcs.exe
RUN pip install boto3
CMD ["python3", "run.py"]

