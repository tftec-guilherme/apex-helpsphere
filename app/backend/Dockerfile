FROM python:3.13-bookworm

# Install MS ODBC Driver 18 for SQL Server (necessário para aioodbc/pyodbc)
# HelpSphere — Story 06.5a Sessão 2.3
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl gnupg ca-certificates \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
       | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && curl -fsSL https://packages.microsoft.com/config/debian/12/prod.list \
       | tee /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 unixodbc-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ./ /app

RUN python -m pip install -r requirements.txt

RUN python -m pip install gunicorn

CMD ["python3", "-m", "gunicorn", "-b", "0.0.0.0:8000", "main:app"]
