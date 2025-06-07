FROM python:3.9.21-bookworm AS base

WORKDIR /app

COPY requirements.txt requirements.txt

RUN pip install -r requirements.txt && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists

COPY . .

RUN groupadd -r user && \ 
    useradd -g user -m -s /bin/bash user && \
    chown -R user:user /app

USER user

ENTRYPOINT ["/bin/bash", "-c", "set -eo pipefail && make run"]