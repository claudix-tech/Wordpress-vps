.PHONY: help install-deps test create-instance list-instances start-instance stop-instance backup-instance delete-instance clean

PYTHON := python3
WP_MANAGER := $(PYTHON) wp-manager.py
COMPOSE := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; else echo "docker-compose"; fi)

# Default instance name for testing
INSTANCE ?= test-site

help:
	@echo "WordPress Docker Instance Manager - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  install-deps      Install Python dependencies"
	@echo "  create            Create new instance (INSTANCE=mysite)"
	@echo "  list              List all instances"
	@echo "  start             Start instance (INSTANCE=mysite)"
	@echo "  stop              Stop instance (INSTANCE=mysite)"
	@echo "  backup            Backup instance (INSTANCE=mysite)"
	@echo "  delete            Delete instance (INSTANCE=mysite)"
	@echo "  clean             Remove all instances and data"
	@echo "  logs              View logs for instance (INSTANCE=mysite)"
	@echo "  shell-db          Access database shell (INSTANCE=mysite)"
	@echo "  test              Run tests"
	@echo ""
	@echo "Examples:"
	@echo "  make create INSTANCE=mysite"
	@echo "  make start INSTANCE=mysite"
	@echo "  make list"
	@echo "  make backup INSTANCE=mysite"

install-deps:
	@echo "Installing Python dependencies..."
	@$(PYTHON) -m pip install --upgrade pip

create:
	@$(WP_MANAGER) create $(INSTANCE)

list:
	@$(WP_MANAGER) list

start:
	@$(WP_MANAGER) start $(INSTANCE)

stop:
	@$(WP_MANAGER) stop $(INSTANCE)

backup:
	@$(WP_MANAGER) backup $(INSTANCE)

delete:
	@$(WP_MANAGER) delete $(INSTANCE)

logs:
	@if [ -d "instances/$(INSTANCE)" ]; then \
		cd instances/$(INSTANCE) && $(COMPOSE) logs -f; \
	else \
		echo "Instance $(INSTANCE) not found"; \
	fi

shell-db:
	@if [ -d "instances/$(INSTANCE)" ]; then \
		cd instances/$(INSTANCE) && \
		MYSQL_PASSWORD=$$(grep '^MYSQL_PASSWORD=' .env | cut -d'=' -f2) && \
		MYSQL_USER=$$(grep '^MYSQL_USER=' .env | cut -d'=' -f2) && \
		docker exec -it wp-db-$(INSTANCE) mysql -u $$MYSQL_USER -p$$MYSQL_PASSWORD; \
	else \
		echo "Instance $(INSTANCE) not found"; \
	fi

ps:
	@$(COMPOSE) -f instances/$(INSTANCE)/docker-compose.yml ps

stats:
	@$(COMPOSE) -f instances/$(INSTANCE)/docker-compose.yml stats

test:
	@echo "Running tests..."
	@echo "1. Checking Docker installation..."
	@docker --version
	@echo "2. Checking Docker Compose installation..."
	@$(COMPOSE) version
	@echo "3. Testing Python script..."
	@$(WP_MANAGER) --help
	@echo "All tests passed!"

clean:
	@echo "WARNING: This will delete all instances!"
	@read -p "Press enter to continue or Ctrl+C to cancel" confirm
	@rm -rf instances/
	@echo "Cleaned up all instances"

.DEFAULT_GOAL := help
