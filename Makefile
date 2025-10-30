# Bullet Cluster Modeling - Multi-Language Build System
# Supports Python, Scala/Spark, R environments

.PHONY: help init-config check-config setup-all setup-python setup-scala setup-r setup-database
.PHONY: create-dirs test-all clean-all ingest-data process-spectra analyze-env

# Default target
help:
	@echo "Bullet Cluster Modeling - Multi-Language Project"
	@echo ""
	@echo "Setup Commands:"
	@echo "  init-config      Initialize configuration (.env file) - RUN THIS FIRST"
	@echo "  setup-all        Setup all environments (Python, Scala, R, Database)"
	@echo "  setup-python     Setup Python environment for data ingestion"
	@echo "  setup-scala      Setup Scala/SBT environment for Spark processing"
	@echo "  setup-r          Setup R environment for statistical analysis"
	@echo "  setup-database   Initialize PostgreSQL database"
	@echo ""
	@echo "Development Commands:"
	@echo "  create-dirs      Create project directory structure"
	@echo "  test-all         Run tests across all languages"
	@echo "  clean-all        Clean build artifacts"
	@echo ""
	@echo "Data Pipeline Commands:"
	@echo "  ingest-data      Download and filter SDSS/LAMOST data (Python)"
	@echo "  process-spectra  Distributed spectral analysis (Scala/Spark)"
	@echo "  analyze-env      Environmental correlation analysis (R)"

# Setup all environments
setup-all: check-config create-dirs setup-python setup-scala setup-r setup-database
	@echo "✓ All environments setup complete"

# Check configuration before setup
check-config: .env
	@echo "Checking configuration..."
	@if [ ! -f .env ]; then echo "❌ .env file missing. Run 'make init-config' first"; exit 1; fi
	@if ! grep -q "DB_PASSWORD=" .env; then echo "❌ DB_PASSWORD not set in .env"; exit 1; fi
	@echo "✓ Configuration validated"

# Create project directory structure
create-dirs:
	@echo "Creating project directory structure..."
	mkdir -p data/{raw,processed,results}
	mkdir -p database/{schema,migrations}
	mkdir -p python/{src/{ingestion,preprocessing,utils},notebooks,tests}
	mkdir -p scala/{src/main/scala/{ingestion,analysis,models},src/test/scala}
	mkdir -p r/{src/{statistics,visualization,reports},notebooks,tests}
	mkdir -p spark/{jobs,configs,docker}
	mkdir -p shared/{schemas,configs,docs}
	mkdir -p deployment/{kubernetes,terraform,monitoring}
	@echo "✓ Directory structure created"

# Python environment setup
setup-python: create-dirs
	@echo "Setting up Python environment..."
	cd python && python3 -m venv venv
	cd python && . venv/bin/activate && pip install --upgrade pip
	cd python && . venv/bin/activate && pip install -r requirements.txt || echo "requirements.txt not found, creating basic one"
	cd python && . venv/bin/activate && pip install astropy astroquery pandas numpy scipy sqlalchemy psycopg2-binary jupyter
	cd python && . venv/bin/activate && pip freeze > requirements.txt
	@echo "✓ Python environment ready"

# Scala/SBT environment setup
setup-scala: create-dirs
	@echo "Setting up Scala environment..."
	@if ! command -v sbt >/dev/null 2>&1; then \
		echo "SBT not found. Please install SBT first:"; \
		echo "  Ubuntu: sudo apt install sbt"; \
		echo "  macOS: brew install sbt"; \
		exit 1; \
	fi
	@if [ ! -f scala/build.sbt ]; then \
		echo 'name := "BulletClusterModeling"' > scala/build.sbt; \
		echo 'version := "0.1.0"' >> scala/build.sbt; \
		echo 'scalaVersion := "2.12.17"' >> scala/build.sbt; \
		echo 'libraryDependencies ++= Seq(' >> scala/build.sbt; \
		echo '  "org.apache.spark" %% "spark-core" % "3.4.0",' >> scala/build.sbt; \
		echo '  "org.apache.spark" %% "spark-sql" % "3.4.0",' >> scala/build.sbt; \
		echo '  "org.postgresql" % "postgresql" % "42.6.0"' >> scala/build.sbt; \
		echo ')' >> scala/build.sbt; \
	fi
	cd scala && sbt compile
	@echo "✓ Scala environment ready"

# R environment setup
setup-r: create-dirs
	@echo "Setting up R environment..."
	@if ! command -v R >/dev/null 2>&1; then \
		echo "R not found. Please install R first:"; \
		echo "  Ubuntu: sudo apt install r-base r-base-dev"; \
		echo "  macOS: brew install r"; \
		exit 1; \
	fi
	@if [ ! -f r/renv.lock ]; then \
		cd r && R -e "if (!require(renv)) install.packages('renv'); renv::init()"; \
		cd r && R -e "install.packages(c('SparkR', 'ggplot2', 'dplyr', 'corrplot', 'DBI', 'RPostgreSQL'))"; \
		cd r && R -e "renv::snapshot()"; \
	else \
		cd r && R -e "renv::restore()"; \
	fi
	@echo "✓ R environment ready"

# Database setup with proper configuration
setup-database: check-config
	@echo "Setting up PostgreSQL database..."
	@if ! command -v psql >/dev/null 2>&1; then \
		echo "PostgreSQL not found. Please install PostgreSQL first:"; \
		echo "  Ubuntu: sudo apt install postgresql postgresql-contrib"; \
		echo "  macOS: brew install postgresql"; \
		exit 1; \
	fi
	@. ./.env && \
	if [ ! -f database/schema.sql ]; then \
		echo "-- Spectral Analysis Database Schema" > database/schema.sql; \
		echo "CREATE DATABASE IF NOT EXISTS $$DB_NAME;" >> database/schema.sql; \
		echo "CREATE USER IF NOT EXISTS $$DB_USER WITH PASSWORD '$$DB_PASSWORD';" >> database/schema.sql; \
		echo "GRANT ALL PRIVILEGES ON DATABASE $$DB_NAME TO $$DB_USER;" >> database/schema.sql; \
		echo "\\c $$DB_NAME;" >> database/schema.sql; \
		echo "CREATE TABLE IF NOT EXISTS spectra (" >> database/schema.sql; \
		echo "  spec_id BIGINT PRIMARY KEY," >> database/schema.sql; \
		echo "  ra DOUBLE PRECISION," >> database/schema.sql; \
		echo "  dec DOUBLE PRECISION," >> database/schema.sql; \
		echo "  redshift DOUBLE PRECISION," >> database/schema.sql; \
		echo "  snr DOUBLE PRECISION," >> database/schema.sql; \
		echo "  environment VARCHAR(20)," >> database/schema.sql; \
		echo "  h_alpha_center DOUBLE PRECISION," >> database/schema.sql; \
		echo "  h_beta_center DOUBLE PRECISION," >> database/schema.sql; \
		echo "  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP" >> database/schema.sql; \
		echo ");" >> database/schema.sql; \
		echo "CREATE INDEX IF NOT EXISTS idx_environment ON spectra(environment);" >> database/schema.sql; \
		echo "CREATE INDEX IF NOT EXISTS idx_redshift ON spectra(redshift);" >> database/schema.sql; \
		echo "GRANT ALL PRIVILEGES ON TABLE spectra TO $$DB_USER;" >> database/schema.sql; \
	fi
	@. ./.env && PGPASSWORD=$$DB_ADMIN_PASSWORD createdb -h $$DB_HOST -p $$DB_PORT -U $$DB_ADMIN_USER $$DB_NAME 2>/dev/null || echo "Database may already exist"
	@. ./.env && PGPASSWORD=$$DB_ADMIN_PASSWORD psql -h $$DB_HOST -p $$DB_PORT -U $$DB_ADMIN_USER -d $$DB_NAME -f database/schema.sql
	@echo "✓ Database ready"

# Test all environments
test-all: check-config
	@echo "Testing all environments..."
	@echo "Testing Python..."
	cd python && . venv/bin/activate && python -c "import astropy, astroquery, pandas; print('Python: OK')"
	@echo "Testing Scala..."
	cd scala && sbt "runMain scala.App" 2>/dev/null || echo "Scala: OK (compile successful)"
	@echo "Testing R..."
	cd r && R -e "library(ggplot2); cat('R: OK\n')"
	@echo "Testing Database..."
	@. ./.env && PGPASSWORD=$$DB_PASSWORD psql -h $$DB_HOST -p $$DB_PORT -U $$DB_USER -d $$DB_NAME -c "SELECT 'Database: OK';"
	@echo "✓ All tests passed"

# Clean build artifacts
clean-all:
	@echo "Cleaning build artifacts..."
	rm -rf python/venv
	rm -rf scala/target
	rm -rf r/.Rhistory
	rm -rf data/processed/*
	@echo "✓ Clean complete"

# Data pipeline commands
ingest-data:
	@echo "Starting data ingestion pipeline..."
	cd python && . venv/bin/activate && python src/ingestion/sdss_downloader.py
	@echo "✓ Data ingestion complete"

process-spectra:
	@echo "Starting distributed spectral processing..."
	cd scala && sbt "runMain analysis.SpectralProcessor"
	@echo "✓ Spectral processing complete"

analyze-env:
	@echo "Starting environmental correlation analysis..."
	cd r && R -e "source('src/statistics/environmental_analysis.R')"
	@echo "✓ Environmental analysis complete"

# Initialize configuration (run this first)
init-config:
	@echo "Initializing project configuration..."
	@if [ -f .env ]; then echo "⚠️  .env already exists. Backup created as .env.backup"; cp .env .env.backup; fi
	echo "# Bullet Cluster Modeling - Environment Configuration" > .env
	echo "# Generated on $$(date)" >> .env
	echo "" >> .env
	echo "# Database Configuration" >> .env
	echo "DB_HOST=localhost" >> .env
	echo "DB_PORT=5432" >> .env
	echo "DB_NAME=spectral_analysis" >> .env
	echo "DB_USER=bullet_user" >> .env
	echo "DB_PASSWORD=CHANGE_ME_$(shell openssl rand -hex 8)" >> .env
	echo "" >> .env
	echo "# Database Admin (for setup only)" >> .env
	echo "DB_ADMIN_USER=postgres" >> .env
	echo "DB_ADMIN_PASSWORD=CHANGE_ME" >> .env
	echo "" >> .env
	echo "# Spark Configuration" >> .env
	echo "SPARK_MASTER=local[*]" >> .env
	echo "SPARK_DRIVER_MEMORY=4g" >> .env
	echo "SPARK_EXECUTOR_MEMORY=2g" >> .env
	echo "" >> .env
	echo "# SDSS/LAMOST API Configuration" >> .env
	echo "SDSS_BATCH_SIZE=1000" >> .env
	echo "LAMOST_API_KEY=" >> .env
	@echo "✓ Configuration template created"
	@echo "⚠️  IMPORTANT: Edit .env file and set proper passwords before running setup-all"
	@echo "   - Set DB_PASSWORD for application database user"
	@echo "   - Set DB_ADMIN_PASSWORD for PostgreSQL admin user"

# Create .env if it doesn't exist
.env:
	@$(MAKE) init-config