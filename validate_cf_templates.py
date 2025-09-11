#!/usr/bin/env python3

import yaml
import sys
import re

def validate_cloudformation_yaml(filename):
    """
    Validate CloudFormation YAML by temporarily replacing intrinsic functions
    with placeholder values to check basic YAML structure.
    """
    try:
        with open(filename, 'r') as file:
            content = file.read()
        
        cf_functions = [
            r'!Ref\s+\w+', r'!GetAtt\s+[\w.]+', r'!Sub\s+[\'"][^\'"]*[\'"]',
            r'!Sub\s+\w+', r'!Equals\s+\[.*?\]', r'!If\s+\[.*?\]',
            r'!Not\s+\[.*?\]', r'!And\s+\[.*?\]', r'!Or\s+\[.*?\]',
            r'!Join\s+\[.*?\]', r'!Select\s+\[.*?\]', r'!Split\s+\[.*?\]',
            r'!Base64\s+.*', r'!GetAZs\s+.*', r'!ImportValue\s+.*'
        ]
        
        modified_content = content
        for pattern in cf_functions:
            modified_content = re.sub(pattern, '"CF_FUNCTION_PLACEHOLDER"', modified_content)
        
        modified_content = modified_content.replace('!Ref \'AWS::NoValue\'', '"AWS_NO_VALUE"')
        modified_content = modified_content.replace('!Ref AWS::NoValue', '"AWS_NO_VALUE"')
        
        yaml.safe_load(modified_content)
        print(f'✓ {filename}: CloudFormation YAML structure is valid')
        return True
        
    except yaml.YAMLError as e:
        print(f'✗ {filename}: YAML structure error: {e}')
        return False
    except FileNotFoundError:
        print(f'✗ {filename}: File not found')
        return False
    except Exception as e:
        print(f'✗ {filename}: Validation error: {e}')
        return False

def main():
    templates = ['idle-instance-shutdown.yaml', 'member-account-role.yaml']
    all_valid = True
    
    print("Validating CloudFormation template structure...")
    print("=" * 50)
    
    for template in templates:
        if not validate_cloudformation_yaml(template):
            all_valid = False
    
    print("=" * 50)
    if all_valid:
        print('✓ All CloudFormation templates have valid structure')
        return 0
    else:
        print('✗ One or more templates have structural issues')
        return 1

if __name__ == '__main__':
    sys.exit(main())
