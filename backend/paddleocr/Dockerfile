FROM python:3.10-slim

ENV PYTHONUNBUFFERED=1

RUN apt-get update \
  && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 libgomp1 \
  && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir --upgrade pip \
  && python -m pip install --no-cache-dir paddlepaddle==3.2.0 \
    -i https://www.paddlepaddle.org.cn/packages/stable/cpu/ \
  && python -m pip install --no-cache-dir paddleocr==3.7.0 \
  && paddlex --install serving

EXPOSE 8080

CMD ["paddlex", "--serve", "--pipeline", "OCR", "--device", "cpu", "--host", "0.0.0.0", "--port", "8080"]
