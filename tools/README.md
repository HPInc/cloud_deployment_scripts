# generate_names.py
This is a Python 3 script that generates a bulk user CSV to be used with ../modules/gcp/dc/new_domain_users.ps1.tpl.

The CSV file generated will have random First name, Last name and password.  The username will be [first initial]+[last name].

To run:
```python3 -m venv env
. env/bin/activate
pip install names
python3 generate_names.py 99 > domain_users_list.csv
deactivate
```
