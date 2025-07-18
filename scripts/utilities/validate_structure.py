#!/usr/bin/env python3
# scripts/utilities/validate_structure_enhanced.py - Fixed Version

import os
import json
import yaml
import re
import fnmatch
from pathlib import Path, PurePath
from typing import Dict, List, Tuple, Optional, Set
import argparse

class ComprehensiveProjectValidator:
    def __init__(self, base_path=".", config_file=None):
        self.base_path = Path(base_path).resolve()
        self.config = self._load_config(config_file)
        
        # Results tracking
        self.results = {
            'directories': {
                'found': [],
                'missing': [],
                'empty': [],
                'minimal': [],
                'forbidden': [],
                'misplaced': []
            },
            'files': {
                'found': [],
                'missing': [],
                'empty': [],
                'minimal': [],
                'forbidden': [],
                'misplaced': [],
                'wrong_extension': [],
                'naming_violation': []
            }
        }
        
        # Statistics
        self.stats = {
            'total_dirs_checked': 0,
            'total_files_checked': 0,
            'total_size_bytes': 0,
            'forbidden_items_found': 0,
            'misplaced_items_found': 0
        }

    def _normalize_path(self, path: Path) -> str:
        """Normalize path for consistent comparison (always use forward slashes)"""
        relative_path = path.relative_to(self.base_path)
        # Convert to forward slashes for consistent comparison
        normalized = str(relative_path).replace('\\', '/')
        return normalized

    def _normalize_location(self, location: str) -> str:
        """Normalize location string for comparison"""
        # Handle different representations of root
        if location in ['.', '', 'root']:
            return ''
        # Always use forward slashes
        return location.replace('\\', '/').rstrip('/')

    def _load_config(self, config_file):
        """Load comprehensive validation configuration"""
        default_config = {
            # Content validation
            'min_file_size_bytes': 10,
            'min_dir_items': 1,
            'min_critical_file_size': 100,
            
            # Allowed empty files/dirs
            'ignore_empty_files': [
                '.gitkeep', '.gitignore', '__init__.py', 'CHANGELOG.md'
            ],
            'ignore_empty_dirs': [
                'logs', 'backup/configs', 'backup/user_data', 'backup/logs', '.git'
            ],
            
            # Critical files
            'critical_files': [
                'README.md', 'configs/ansible/ansible.cfg',
                'scripts/deployment/master_deploy.sh',
                'configs/archinstall/user_configuration.json'
            ],
            
            # FORBIDDEN FILES/PATTERNS (Updated - removed .vscode/settings.json)
            'forbidden_files': [
                # Temporary files
                '*.tmp', '*.temp', '*~', '*.bak', '*.backup', '*.orig',
                # OS files
                '.DS_Store', 'Thumbs.db', 'desktop.ini', 'Icon\r',
                # IDE files (made more specific)
                '.idea/*', '*.swp', '*.swo',
                # Compiled files
                '*.pyc', '*.pyo', '__pycache__/*', '*.o', '*.so', '*.exe',
                # Logs in wrong places
                '*.log', 'log.txt', 'debug.log', 'error.log',
                # Secrets that shouldn't be committed
                '*.key', '*.pem', '*.p12', 'id_rsa', 'id_ed25519',
                '*.cert', '*.crt', 'password*', 'secret*',
                # Package managers
                'node_modules/*', 'venv/*', '.env', '*.egg',
                # Build artifacts
                'build/*', 'dist/*', '*.egg-info/*', 'target/*',
                # Archives
                '*.zip', '*.tar.gz', '*.iso', '*.img', '*.deb', '*.rpm'
            ],
            
            # ALLOWED IDE FILES (New section)
            'allowed_ide_files': [
                '.vscode/settings.json',
                '.vscode/extensions.json',
                '.vscode/tasks.json',
                '.vscode/launch.json',
                # Add other IDE files you want to allow
            ],
            
            # FORBIDDEN DIRECTORIES
            'forbidden_directories': [
                '__pycache__', '.pytest_cache', '.mypy_cache',
                'node_modules', 'venv', 'env', '.env',
                'build', 'dist', '.tox',
                'logs/old', 'backup/old'
            ],
            
            # ALLOWED IDE DIRECTORIES (New section)
            'allowed_ide_directories': [
                '.vscode',
                # Add other IDE directories you want to allow
            ],
            
            # FILE LOCATION RULES
            'file_location_rules': {
                # Files that should be in specific directories
                'configs/ansible/': ['*.yml', '*.yaml', 'ansible.cfg'],
                'configs/archinstall/': ['*.json'],
                'scripts/': ['*.sh'],
                'templates/': ['*.j2', '*.jinja2'],
                'docs/': ['*.md', '*.rst', '*.txt'],
                'tests/': ['test_*.py', '*_test.py'],
                
                # Files that should NOT be in certain directories
                'root_forbidden': ['*.sh', '*.py', '*.yml', '*.yaml'],
                'configs_forbidden': ['*.sh', '*.py'],
                'docs_forbidden': ['*.sh', '*.py', '*.yml']
            },
            
            # NAMING CONVENTIONS
            'naming_rules': {
                'scripts': {
                    'pattern': r'^[a-z0-9_]+\.sh$',
                    'description': 'Scripts should be lowercase with underscores, ending in .sh'
                },
                'ansible_files': {
                    'pattern': r'^[a-z0-9_]+\.(yml|yaml)$',
                    'description': 'Ansible files should be lowercase with underscores'
                },
                'roles': {
                    'pattern': r'^[a-z0-9_]+$',
                    'description': 'Role names should be lowercase with underscores'
                },
                'python_files': {
                    'pattern': r'^[a-z0-9_]+\.py$',
                    'description': 'Python files should be lowercase with underscores'
                }
            },
            
            # EXPECTED FILE LOCATIONS (Fixed - using consistent notation)
            'expected_locations': {
                'ansible.cfg': 'configs/ansible',
                'requirements.txt': '',  # Root directory
                'Makefile': '',         # Root directory
                'README.md': '',        # Root directory
                'LICENSE': '',          # Root directory
                '.gitignore': ''        # Root directory
            }
        }
        
        if config_file and Path(config_file).exists():
            try:
                with open(config_file, 'r') as f:
                    if config_file.endswith('.json'):
                        user_config = json.load(f)
                    else:
                        user_config = yaml.safe_load(f)
                default_config.update(user_config)
            except Exception as e:
                print(f"Warning: Could not load config file {config_file}: {e}")
        
        return default_config

    def _is_forbidden_file(self, file_path: Path) -> Tuple[bool, str]:
        """Check if file matches forbidden patterns (with IDE exceptions)"""
        normalized_path = self._normalize_path(file_path)
        file_name = file_path.name
        
        # Check if it's an allowed IDE file first
        if normalized_path in self.config.get('allowed_ide_files', []):
            return False, ""
        
        # Check forbidden patterns
        for pattern in self.config['forbidden_files']:
            if fnmatch.fnmatch(file_name, pattern) or fnmatch.fnmatch(normalized_path, pattern):
                return True, f"Matches forbidden pattern: {pattern}"
                
        return False, ""

    def _is_forbidden_directory(self, dir_path: Path) -> Tuple[bool, str]:
        """Check if directory is forbidden (with IDE exceptions)"""
        normalized_path = self._normalize_path(dir_path)
        dir_name = dir_path.name
        
        # Check if it's an allowed IDE directory first
        if normalized_path in self.config.get('allowed_ide_directories', []):
            return False, ""
        
        # Check forbidden directories
        for forbidden_dir in self.config['forbidden_directories']:
            if dir_name == forbidden_dir or normalized_path == forbidden_dir:
                return True, f"Forbidden directory: {forbidden_dir}"
                
        return False, ""

    def _check_file_placement(self, file_path: Path) -> Tuple[bool, str]:
        """Check if file is in the correct location (Fixed path comparison)"""
        normalized_path = self._normalize_path(file_path)
        file_name = file_path.name
        
        # Get the parent directory in normalized form
        parent_parts = file_path.relative_to(self.base_path).parts[:-1]
        if parent_parts:
            parent_dir = '/'.join(parent_parts)
        else:
            parent_dir = ''  # Root directory
        
        # Check expected locations
        if file_name in self.config['expected_locations']:
            expected_location = self._normalize_location(self.config['expected_locations'][file_name])
            actual_location = self._normalize_location(parent_dir)
            
            if expected_location != actual_location:
                expected_display = expected_location if expected_location else 'root'
                actual_display = actual_location if actual_location else 'root'
                return False, f"Should be in '{expected_display}' but found in '{actual_display}'"
        
        # Check file type rules
        for location, patterns in self.config['file_location_rules'].items():
            if location.endswith('/'):  # Directory rule
                location_normalized = self._normalize_location(location.rstrip('/'))
                if parent_dir == location_normalized or parent_dir.startswith(location_normalized + '/'):
                    # File is in this directory, check if it should be
                    should_be_here = any(fnmatch.fnmatch(file_name, pattern) for pattern in patterns)
                    if not should_be_here:
                        # Check if it matches forbidden patterns for this location
                        forbidden_key = location.rstrip('/').replace('/', '_') + '_forbidden'
                        if forbidden_key in self.config['file_location_rules']:
                            forbidden_patterns = self.config['file_location_rules'][forbidden_key]
                            if any(fnmatch.fnmatch(file_name, pattern) for pattern in forbidden_patterns):
                                return False, f"File type '{file_name}' not allowed in '{location_normalized}'"
        
        # Check root directory restrictions
        if parent_dir == '':
            forbidden_in_root = self.config['file_location_rules'].get('root_forbidden', [])
            if any(fnmatch.fnmatch(file_name, pattern) for pattern in forbidden_in_root):
                return False, f"File type '{file_name}' should not be in project root"
        
        return True, ""

    def _check_naming_convention(self, file_path: Path) -> Tuple[bool, str]:
        """Check if file follows naming conventions"""
        file_name = file_path.name
        normalized_path = self._normalize_path(file_path)
        
        # Determine file category
        if file_path.suffix == '.sh':
            rule = self.config['naming_rules'].get('scripts')
        elif file_path.suffix in ['.yml', '.yaml'] and 'ansible' in normalized_path:
            rule = self.config['naming_rules'].get('ansible_files')
        elif file_path.suffix == '.py':
            rule = self.config['naming_rules'].get('python_files')
        elif 'roles' in normalized_path and file_path.is_dir():
            rule = self.config['naming_rules'].get('roles')
        else:
            return True, ""  # No specific rule
        
        if rule and 'pattern' in rule:
            if not re.match(rule['pattern'], file_name):
                return False, rule['description']
        
        return True, ""

    def _scan_all_files_and_dirs(self) -> Tuple[List[Path], List[Path]]:
        """Scan all files and directories in the project"""
        all_files = []
        all_dirs = []
        
        for item in self.base_path.rglob('*'):
            # Skip .git directory entirely
            if '.git' in item.parts:
                continue
                
            if item.is_file():
                all_files.append(item)
            elif item.is_dir():
                all_dirs.append(item)
                
        return all_files, all_dirs

    def check_for_forbidden_and_misplaced(self):
        """Comprehensive scan for forbidden and misplaced items"""
        print("🔍 Scanning for forbidden and misplaced items...\n")
        
        all_files, all_dirs = self._scan_all_files_and_dirs()
        
        # Check files
        print("📄 Checking files for violations...")
        for file_path in all_files:
            normalized_path = self._normalize_path(file_path)
            
            # Check if forbidden
            is_forbidden, forbidden_reason = self._is_forbidden_file(file_path)
            if is_forbidden:
                self.results['files']['forbidden'].append({
                    'path': normalized_path,
                    'reason': forbidden_reason,
                    'size': file_path.stat().st_size if file_path.exists() else 0
                })
                self.stats['forbidden_items_found'] += 1
                print(f"  🚫 {normalized_path} - {forbidden_reason}")
                continue
            
            # Check placement
            is_well_placed, placement_reason = self._check_file_placement(file_path)
            if not is_well_placed:
                self.results['files']['misplaced'].append({
                    'path': normalized_path,
                    'reason': placement_reason,
                    'size': file_path.stat().st_size if file_path.exists() else 0
                })
                self.stats['misplaced_items_found'] += 1
                print(f"  📍 {normalized_path} - {placement_reason}")
            
            # Check naming convention
            follows_naming, naming_reason = self._check_naming_convention(file_path)
            if not follows_naming:
                self.results['files']['naming_violation'].append({
                    'path': normalized_path,
                    'reason': naming_reason,
                    'size': file_path.stat().st_size if file_path.exists() else 0
                })
                print(f"  📝 {normalized_path} - {naming_reason}")
        
        # Check directories
        print(f"\n📁 Checking directories for violations...")
        for dir_path in all_dirs:
            normalized_path = self._normalize_path(dir_path)
            
            # Check if forbidden
            is_forbidden, forbidden_reason = self._is_forbidden_directory(dir_path)
            if is_forbidden:
                self.results['directories']['forbidden'].append({
                    'path': normalized_path,
                    'reason': forbidden_reason,
                    'item_count': len(list(dir_path.iterdir())) if dir_path.exists() else 0
                })
                self.stats['forbidden_items_found'] += 1
                print(f"  🚫 {normalized_path}/ - {forbidden_reason}")
                continue
            
            # Check role naming if in roles directory
            if 'roles' in normalized_path and normalized_path.count('/') == 2:  # configs/ansible/roles/role_name
                follows_naming, naming_reason = self._check_naming_convention(dir_path)
                if not follows_naming:
                    self.results['directories']['misplaced'].append({
                        'path': normalized_path,
                        'reason': naming_reason,
                        'item_count': len(list(dir_path.iterdir())) if dir_path.exists() else 0
                    })
                    print(f"  📝 {normalized_path}/ - {naming_reason}")

    # Keep all other methods from the previous version...
    # (The rest of the methods remain the same)

    def _check_file_content(self, file_path: Path) -> Tuple[str, Dict]:
        """Check if file has meaningful content"""
        info = {
            'size': 0,
            'is_empty': True,
            'is_minimal': False,
            'is_critical': False,
            'type': 'unknown'
        }
        
        try:
            stat = file_path.stat()
            info['size'] = stat.st_size
            self.stats['total_size_bytes'] += stat.st_size
            
            # Determine file type
            if file_path.suffix in ['.py', '.sh', '.yml', '.yaml', '.json']:
                info['type'] = 'config/script'
            elif file_path.suffix in ['.md', '.txt', '.rst']:
                info['type'] = 'documentation'
            elif file_path.suffix in ['.j2', '.jinja2']:
                info['type'] = 'template'
            else:
                info['type'] = 'other'
            
            # Check if file is in critical files list
            normalized_path = self._normalize_path(file_path)
            info['is_critical'] = normalized_path in self.config['critical_files']
            
            # Check content status
            if stat.st_size == 0:
                info['is_empty'] = True
            elif info['is_critical'] and stat.st_size < self.config['min_critical_file_size']:
                info['is_empty'] = False
                info['is_minimal'] = True
            elif stat.st_size < self.config['min_file_size_bytes']:
                info['is_empty'] = False
                info['is_minimal'] = True
            else:
                info['is_empty'] = False
                info['is_minimal'] = False
                
        except Exception as e:
            print(f"Error checking file {file_path}: {e}")
            
        return self._determine_file_status(file_path, info), info

    def _determine_file_status(self, file_path: Path, info: Dict) -> str:
        """Determine the status of a file"""
        if info['is_empty']:
            if file_path.name in self.config['ignore_empty_files']:
                return "empty_allowed"
            else:
                return "empty_problematic"
        elif info['is_minimal']:
            if info['is_critical']:
                return "minimal_critical"
            else:
                return "minimal_normal"
        else:
            return "good"

    def _check_directory_content(self, dir_path: Path) -> Tuple[str, Dict]:
        """Check if directory has meaningful content"""
        info = {
            'item_count': 0,
            'file_count': 0,
            'dir_count': 0,
            'total_size': 0,
            'has_important_files': False
        }
        
        try:
            items = list(dir_path.iterdir())
            info['item_count'] = len(items)
            
            for item in items:
                if item.is_file():
                    info['file_count'] += 1
                    try:
                        size = item.stat().st_size
                        info['total_size'] += size
                        
                        # Check for important file types
                        if item.suffix in ['.py', '.sh', '.yml', '.yaml', '.json', '.j2']:
                            info['has_important_files'] = True
                    except:
                        pass
                elif item.is_dir():
                    info['dir_count'] += 1
                    
        except Exception as e:
            print(f"Error checking directory {dir_path}: {e}")
            
        return self._determine_directory_status(dir_path, info), info

    def _determine_directory_status(self, dir_path: Path, info: Dict) -> str:
        """Determine the status of a directory"""
        normalized_path = self._normalize_path(dir_path)
        
        if info['item_count'] == 0:
            if any(normalized_path.startswith(ignored) for ignored in self.config['ignore_empty_dirs']):
                return "empty_allowed"
            else:
                return "empty_problematic"
        elif info['item_count'] < self.config['min_dir_items'] and not info['has_important_files']:
            return "minimal"
        else:
            return "good"

    def check_file(self, file_path: str, optional: bool = False) -> bool:
        """Enhanced file checking with content validation"""
        self.stats['total_files_checked'] += 1
        path = self.base_path / file_path
        
        if not path.exists():
            self.results['files']['missing'].append({
                'path': file_path,
                'optional': optional,
                'reason': 'File does not exist'
            })
            return False
            
        if not path.is_file():
            self.results['files']['missing'].append({
                'path': file_path,
                'optional': optional,
                'reason': 'Path exists but is not a file'
            })
            return False
            
        status, info = self._check_file_content(path)
        
        result = {
            'path': file_path,
            'optional': optional,
            'status': status,
            'size': info['size'],
            'type': info['type'],
            'is_critical': info['is_critical']
        }
        
        if status == "good":
            self.results['files']['found'].append(result)
            return True
        elif status in ["empty_allowed"]:
            self.results['files']['found'].append(result)
            return True
        elif status in ["empty_problematic"]:
            self.results['files']['empty'].append(result)
            return False
        elif status in ["minimal_critical", "minimal_normal"]:
            self.results['files']['minimal'].append(result)
            return status != "minimal_critical"
            
        return False

    def check_directory(self, dir_path: str, optional: bool = False) -> bool:
        """Enhanced directory checking with content validation"""
        self.stats['total_dirs_checked'] += 1
        path = self.base_path / dir_path
        
        if not path.exists():
            self.results['directories']['missing'].append({
                'path': dir_path,
                'optional': optional,
                'reason': 'Directory does not exist'
            })
            return False
            
        if not path.is_dir():
            self.results['directories']['missing'].append({
                'path': dir_path,
                'optional': optional,
                'reason': 'Path exists but is not a directory'
            })
            return False
            
        status, info = self._check_directory_content(path)
        
        result = {
            'path': dir_path,
            'optional': optional,
            'status': status,
            'item_count': info['item_count'],
            'file_count': info['file_count'],
            'dir_count': info['dir_count'],
            'total_size': info['total_size'],
            'has_important_files': info['has_important_files']
        }
        
        if status == "good":
            self.results['directories']['found'].append(result)
            return True
        elif status == "empty_allowed":
            self.results['directories']['found'].append(result)
            return True
        elif status == "empty_problematic":
            self.results['directories']['empty'].append(result)
            return False
        elif status == "minimal":
            self.results['directories']['minimal'].append(result)
            return True
            
        return False

    def _print_status_icon(self, status: str, optional: bool = False) -> str:
        """Return appropriate status icon"""
        icons = {
            'good': '✅',
            'empty_allowed': '🔵',
            'empty_problematic': '❌',
            'minimal': '⚠️',
            'minimal_critical': '🔴',
            'minimal_normal': '🟡'
        }
        
        if optional and status in ['empty_problematic', 'minimal_critical']:
            return '🔵'
            
        return icons.get(status, '❓')

    def _format_size(self, size_bytes: int) -> str:
        """Format file size in human readable format"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size_bytes < 1024.0:
                return f"{size_bytes:.1f}{unit}"
            size_bytes /= 1024.0
        return f"{size_bytes:.1f}TB"

    def detect_common_antipatterns(self):
        """Detect common organizational anti-patterns"""
        print("🔍 Detecting common anti-patterns...\n")
        
        antipatterns = []
        
        # 1. Multiple README files
        readme_files = list(self.base_path.rglob('README*'))
        if len(readme_files) > 1:
            antipatterns.append({
                'type': 'multiple_readmes',
                'severity': 'warning',
                'message': f"Multiple README files found: {[self._normalize_path(f) for f in readme_files]}"
            })
        
        # 2. Scripts in wrong places
        root_scripts = list(self.base_path.glob('*.sh'))
        if root_scripts:
            antipatterns.append({
                'type': 'scripts_in_root',
                'severity': 'error',
                'message': f"Scripts in project root should be in scripts/: {[f.name for f in root_scripts]}"
            })
        
        # 3. Config files scattered
        scattered_configs = []
        for pattern in ['*.yml', '*.yaml', '*.json', '*.cfg', '*.ini']:
            for config_file in self.base_path.glob(pattern):
                if config_file.name not in ['requirements.txt', 'Makefile', '.gitignore']:
                    normalized = self._normalize_path(config_file)
                    if not normalized.startswith('configs/'):
                        scattered_configs.append(normalized)
        
        if scattered_configs:
            antipatterns.append({
                'type': 'scattered_configs',
                'severity': 'warning',
                'message': f"Config files outside configs/ directory: {scattered_configs}"
            })
        
        # 4. Deep nesting (>4 levels)
        deep_paths = []
        for item in self.base_path.rglob('*'):
            if '.git' in item.parts:
                continue
            normalized = self._normalize_path(item)
            if normalized.count('/') > 4:
                deep_paths.append(normalized)
        
        if deep_paths:
            antipatterns.append({
                'type': 'deep_nesting',
                'severity': 'warning',
                'message': f"Very deep directory nesting (>4 levels): {deep_paths[:5]}{'...' if len(deep_paths) > 5 else ''}"
            })
        
        # 5. Empty critical directories
        critical_dirs = ['configs/ansible/roles', 'scripts/bootstrap', 'docs']
        for dir_path in critical_dirs:
            full_path = self.base_path / dir_path
            if full_path.exists():
                if not any(full_path.iterdir()):
                    antipatterns.append({
                        'type': 'empty_critical_dir',
                        'severity': 'error',
                        'message': f"Critical directory is empty: {dir_path}"
                    })
        
        # Report anti-patterns
        if antipatterns:
            print("⚠️  Anti-patterns detected:")
            for pattern in antipatterns:
                severity_icon = {'error': '🔴', 'warning': '🟡', 'info': '🔵'}
                icon = severity_icon.get(pattern['severity'], '❓')
                print(f"  {icon} [{pattern['severity'].upper()}] {pattern['message']}")
        else:
            print("✅ No anti-patterns detected!")
        
        return antipatterns

    def check_structure(self):
        """Main validation function with comprehensive checking"""
        print("🔍 Comprehensive Arch Linux Hyprland Project Structure Validation\n")
        
        # First, check for forbidden and misplaced items
        self.check_for_forbidden_and_misplaced()
        
        # Detect anti-patterns
        antipatterns = self.detect_common_antipatterns()
        
        # Then do the standard structure validation
        print(f"\n📋 Checking expected project structure...")
        
        # Define expected structure
        expected_structure = {
            "directories": [
                ("docs", False),
                ("configs/archinstall", False),
                ("configs/ansible/inventory", False),
                ("configs/ansible/group_vars/all", False),
                ("configs/ansible/host_vars/phoenix", True),
                ("configs/ansible/playbooks", False),
                ("configs/ansible/roles", False),
                ("configs/profiles/work", True),
                ("configs/profiles/personal", True),
                ("configs/profiles/development", True),
                ("scripts/bootstrap", False),
                ("scripts/deployment", False),
                ("scripts/maintenance", False),
                ("scripts/security", True),
                ("scripts/utilities", False),
                ("scripts/testing", True),
                ("templates/systemd/services", True),
                ("templates/systemd/timers", True),
                ("templates/configs", True),
                ("files/wallpapers", True),
                ("files/fonts", True),
                ("files/themes", True),
                ("tests/unit", True),
                ("tests/integration", True),
                ("tests/validation", True),
                ("backup", False),
                ("logs", False)
            ],
            "files": [
                ("README.md", False),
                ("LICENSE", True),
                (".gitignore", False),
                ("requirements.txt", False),
                ("Makefile", False),
                ("CHANGELOG.md", True),
                ("configs/ansible/ansible.cfg", False),
                ("configs/ansible/requirements.yml", False),
                ("configs/archinstall/user_configuration.json", False),
                ("configs/archinstall/user_credentials.json", True),
                ("scripts/deployment/master_deploy.sh", False),
                ("scripts/bootstrap/bootstrap.sh", False),
                ("scripts/bootstrap/first_boot_setup.sh", False),
                ("scripts/maintenance/health_check.sh", False),
                ("scripts/utilities/validate_structure.sh", True)
            ],
            "ansible_roles": [
                "base_system", "users_security", "hyprland_desktop",
                "aur_packages", "system_hardening", "power_management",
                "development_tools", "monitoring", "user_environment"
            ]
        }
        
        # Check directories
        print("📁 Checking directories...")
        for directory, optional in expected_structure["directories"]:
            self.check_directory(directory, optional)
        
        # Check files
        print("\n📄 Checking key files...")
        for file_path, optional in expected_structure["files"]:
            self.check_file(file_path, optional)
        
        # Check Ansible roles
        print("\n🎭 Checking Ansible roles...")
        roles_path = self.base_path / "configs/ansible/roles"
        if roles_path.exists():
            for role in expected_structure["ansible_roles"]:
                role_path = roles_path / role
                if role_path.exists():
                    _, info = self._check_directory_content(role_path)
                    icon = '✅' if info['has_important_files'] else '⚠️'
                    print(f"  {icon} Role: {role} ({info['item_count']} items)")
                else:
                    print(f"  ❌ Role: {role} (missing)")
        else:
            print("  ❌ Roles directory not found")
        
        # Generate comprehensive report
        self._generate_comprehensive_report(antipatterns)

    def _generate_comprehensive_report(self, antipatterns):
        """Generate comprehensive validation report"""
        print("\n" + "="*80)
        print("📊 COMPREHENSIVE VALIDATION REPORT")
        print("="*80)
        
        # Basic statistics
        print(f"📈 Statistics:")
        print(f"  Directories checked: {self.stats['total_dirs_checked']}")
        print(f"  Files checked: {self.stats['total_files_checked']}")
        print(f"  Total project size: {self._format_size(self.stats['total_size_bytes'])}")
        print(f"  Forbidden items found: {self.stats['forbidden_items_found']}")
        print(f"  Misplaced items found: {self.stats['misplaced_items_found']}")
        
        # Violations summary
        violations = []
        
        if self.results['files']['forbidden'] or self.results['directories']['forbidden']:
            violations.append("Forbidden files/directories present")
            print(f"\n🚫 FORBIDDEN ITEMS:")
            for item in self.results['files']['forbidden']:
                print(f"  📄 {item['path']} - {item['reason']}")
            for item in self.results['directories']['forbidden']:
                print(f"  📁 {item['path']}/ - {item['reason']}")
        
        if self.results['files']['misplaced'] or self.results['directories']['misplaced']:
            violations.append("Misplaced files/directories")
            print(f"\n📍 MISPLACED ITEMS:")
            for item in self.results['files']['misplaced']:
                print(f"  📄 {item['path']} - {item['reason']}")
            for item in self.results['directories']['misplaced']:
                print(f"  📁 {item['path']}/ - {item['reason']}")
        
        if self.results['files']['naming_violation']:
            violations.append("Naming convention violations")
            print(f"\n📝 NAMING VIOLATIONS:")
            for item in self.results['files']['naming_violation']:
                print(f"  📄 {item['path']} - {item['reason']}")
        
        # Anti-patterns
        if antipatterns:
            error_patterns = [p for p in antipatterns if p['severity'] == 'error']
            warning_patterns = [p for p in antipatterns if p['severity'] == 'warning']
            
            if error_patterns:
                violations.append("Organizational anti-patterns (errors)")
            if warning_patterns:
                violations.append("Organizational anti-patterns (warnings)")
        
        # Content issues
        critical_issues = [f for f in self.results['files']['minimal'] if f.get('is_critical')]
        if critical_issues:
            violations.append("Critical files with minimal content")
            print(f"\n🔴 Critical Files with Minimal Content:")
            for file in critical_issues:
                print(f"  📄 {file['path']} ({self._format_size(file['size'])})")
        
        # Recommendations
        print(f"\n💡 RECOMMENDATIONS:")
        if self.results['files']['forbidden'] or self.results['directories']['forbidden']:
            print("  🧹 Remove or move forbidden files/directories")
        
        if self.results['files']['misplaced'] or self.results['directories']['misplaced']:
            print("  📁 Move misplaced files to correct locations")
        
        if self.results['files']['naming_violation']:
            print("  📝 Rename files to follow naming conventions")
        
        # Overall status
        print(f"\n{'='*80}")
        if not violations:
            print("🎉 Project structure is well-organized and follows best practices!")
            return True
        else:
            print(f"⚠️  Found {len(violations)} categories of issues:")
            for i, violation in enumerate(violations, 1):
                print(f"  {i}. {violation}")
            return False

    def export_report(self, output_file: str = "comprehensive_validation_report.json"):
        """Export detailed report to JSON file"""
        report = {
            'timestamp': str(self.base_path),
            'config': self.config,
            'statistics': self.stats,
            'results': self.results,
            'summary': {
                'total_violations': (
                    len(self.results['files']['forbidden']) +
                    len(self.results['directories']['forbidden']) +
                    len(self.results['files']['misplaced']) +
                    len(self.results['directories']['misplaced']) +
                    len(self.results['files']['naming_violation'])
                )
            }
        }
        
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        print(f"\n📋 Detailed report exported to: {output_file}")

def main():
    parser = argparse.ArgumentParser(description='Comprehensive Project Structure Validator')
    parser.add_argument('--path', default='.', help='Path to project root (default: current directory)')
    parser.add_argument('--config', help='Path to validation config file (JSON or YAML)')
    parser.add_argument('--export', help='Export detailed report to file')
    parser.add_argument('--violations-only', action='store_true', help='Only check for violations (forbidden/misplaced)')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    # Run validation
    validator = ComprehensiveProjectValidator(args.path, args.config)
    
    if args.violations_only:
        validator.check_for_forbidden_and_misplaced()
        validator.detect_common_antipatterns()
    else:
        success = validator.check_structure()
    
    # Export report if requested
    if args.export:
        validator.export_report(args.export)
    
    # Exit with appropriate code
    total_violations = (
        len(validator.results['files']['forbidden']) +
        len(validator.results['directories']['forbidden']) +
        len(validator.results['files']['misplaced']) +
        len(validator.results['directories']['misplaced']) +
        len(validator.results['files']['naming_violation'])
    )
    
    exit(0 if total_violations == 0 else 1)

if __name__ == "__main__":
    main()