FROM python:3.13-alpine
ADD requirements.txt /requirements.txt
RUN pip3 install --no-cache-dir -r /requirements.txt
ADD docker-registry-cleanup.py /docker-registry-cleanup.py
CMD python3 /docker-registry-cleanup.py
