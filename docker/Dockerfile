FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y wireguard wireguard-tools openssl

COPY docker/requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ src/

EXPOSE 8000 1194/udp

CMD ["python", "src/main.py"]
