.PHONY: install test deploy clean

install:
	pip install -r requirements.txt
	ansible-galaxy collection install -r configs/ansible/requirements.yml

test:
	ansible-playbook --syntax-check configs/ansible/playbooks/site.yml
	python -m pytest tests/

deploy:
	./scripts/deployment/master_deploy.sh full

clean:
	rm -rf logs/*
	rm -rf backup/configs/*
	rm -rf backup/user_data/*

validate:
	ansible-lint configs/ansible/playbooks/
	python tests/validation/validate_system.py

usb:
	sudo ./scripts/bootstrap/prepare_usb.sh

health:
	./scripts/maintenance/health_check.sh

check-structure:
	@echo "Quick structure check..."
	@for dir in docs configs scripts files tests; do \
		[ -d "$$dir" ] && echo "✅ $$dir" || echo "❌ $$dir"; \
	done
	@echo "Ansible roles: $$(find configs/ansible/roles/ -maxdepth 1 -type d 2>/dev/null | wc -l)/9"

# Enhanced validation targets
validate-content:
	./scripts/utilities/validate_structure_enhanced.py

quick-content:
	./scripts/utilities/quick_content_check.sh

validate-full:
	./scripts/utilities/validate_structure_enhanced.py --config configs/validation_config.yml --export validation_report.json

check-critical:
	@echo "Checking critical files..."
	@for file in README.md configs/ansible/ansible.cfg scripts/deployment/master_deploy.sh; do \
		if [ -f "$$file" ]; then \
			size=$$(stat -c%s "$$file" 2>/dev/null || stat -f%z "$$file" 2>/dev/null); \
			if [ "$$size" -gt 100 ]; then \
				echo "✅ $$file ($${size} bytes)"; \
			else \
				echo "⚠️  $$file ($${size} bytes - too small)"; \
			fi; \
		else \
			echo "❌ $$file (missing)"; \
		fi; \
	done

# Comprehensive validation targets
validate-comprehensive:
	./scripts/utilities/validate_structure_enhanced.py --config configs/validation_config.yml

check-violations:
	./scripts/utilities/quick_violations_check.sh

validate-violations-only:
	./scripts/utilities/validate_structure_enhanced.py --violations-only

clean-violations:
	@echo "🧹 Cleaning common violations..."
	find . -name "*.tmp" -delete 2>/dev/null || true
	find . -name "*.bak" -delete 2>/dev/null || true
	find . -name "*~" -delete 2>/dev/null || true
	find . -name ".DS_Store" -delete 2>/dev/null || true
	find . -name "Thumbs.db" -delete 2>/dev/null || true
	find . -name "*.pyc" -delete 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@echo "✅ Common violations cleaned"

validate-full-report:
	./scripts/utilities/validate_structure_enhanced.py --config configs/validation_config.yml --export validation_report.json
	@echo "📋 Full report saved to validation_report.json"