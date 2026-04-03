#!/opt/tethys-python
import sys
import os
from importlib.metadata import version as get_version, PackageNotFoundError
from packaging import version
from packaging.specifiers import SpecifierSet

# Track failures
failures = []
checks_passed = 0
checks_total = 0


def check_package_version(package_name, requirement_spec, failures_list):
    """
    Check if a package meets version requirements.
    
    Args:
        package_name: Name of the package to check
        requirement_spec: Version requirement (e.g., '>2.4.1', '==2.1.7', '>=7.9.22,<8.0.0')
        failures_list: List to append failure messages to
    
    Returns:
        bool: True if check passed, False otherwise
    """
    global checks_total, checks_passed
    checks_total += 1
    
    try:
        installed_version = get_version(package_name)
        
        # Handle special case for "greater than" check
        if requirement_spec.startswith('>') and not requirement_spec.startswith('>='):
            required_ver = version.parse(requirement_spec.lstrip('>'))
            installed_ver = version.parse(installed_version)
            
            if installed_ver <= required_ver:
                msg = f'ERROR: {package_name} version {installed_version} is not greater than {requirement_spec.lstrip(">")}'
                print(msg)
                failures_list.append(msg)
                return False
            else:
                print(f'OK: {package_name} version {installed_version} meets requirement ({requirement_spec})')
                checks_passed += 1
                return True
        else:
            # Use SpecifierSet for standard version specifiers
            # Remove leading == if present for cleaner specifier creation
            clean_spec = requirement_spec.lstrip('=')
            if requirement_spec.startswith('=='):
                specifier = SpecifierSet(f'=={clean_spec}')
            else:
                specifier = SpecifierSet(requirement_spec)
            
            if installed_version not in specifier:
                msg = f'ERROR: {package_name} version {installed_version} does not match requirement {requirement_spec}'
                print(msg)
                failures_list.append(msg)
                return False
            else:
                print(f'OK: {package_name} version {installed_version} meets requirement {requirement_spec}')
                checks_passed += 1
                return True
                
    except PackageNotFoundError:
        msg = f'ERROR: {package_name} is not installed'
        print(msg)
        failures_list.append(msg)
        return False


if __name__ == '__main__':
    # Check tethys_dataset_services version
    check_package_version('tethys_dataset_services', '>=2.4.1', failures)

    # Check GDAL version
    try:
        from osgeo import gdal_array
    except ImportError as e:
        msg = f'ERROR: GDAL is not installed properly: {e}'
        print(msg)
        failures.append(msg)

    # Print summary
    print('\n' + '=' * 60)
    print(f'ENFORCED VERSION CHECK SUMMARY: {checks_passed}/{checks_total} checks passed')
    print('=' * 60)

    if failures:
        print(f'\n{len(failures)} error(s) found:\n')
        for failure in failures:
            print(f'{failure}')
        print('\nEnforced Version check FAILED!')
        sys.exit(1)
    else:
        print('\nAll enforced version checks PASSED!')
        sys.exit(0)

