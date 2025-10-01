FROM python:3.9-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app code
COPY . .

# Expose the API port
EXPOSE 8080

# Run the app (change app.py to your entrypoint file)
CMD ["python", "app.py"]
