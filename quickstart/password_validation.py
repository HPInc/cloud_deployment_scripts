#!/usr/bin/env python3

# Copyright (c) 2021 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import getpass
import re
import textwrap
import time
 
def ad_password_get(username):
    txt = r'''
    Please enter a password for the Active Directory Administrator.

    Note Windows passwords must be at least 7 characters long and meet complexity
    requirements:
    1. Must not contain user's account name or display name
    2. Must have 3 of the following categories:
       - a-z
       - A-Z
       - 0-9
       - special characters: ~!@#$%^&*_-+=`|\(){}[]:;"'<>,.?/
       - unicode characters
    See: https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements
    '''
    print(textwrap.dedent(txt))

    while True:
        password1 = getpass.getpass('Enter a password: ').strip()
        if not ad_password_validate(password1, username):
            print("Please try again.")
            continue
        password2 = getpass.getpass('Re-enter the password: ').strip()
        if password1 == password2:
            break
        print(f'The passwords do not match. Please try again.')
    print('')

    return password1

def ad_password_validate(password, username):

    # delimeters are specified in the microsoft documentation
    username_parsed = re.split("[—,.\-\_#\s\t]", username)
    for u in username_parsed:
        if len(u) < 3:
            continue
        if re.search(u, password, re.IGNORECASE):
            print("Password cannot contain username.", end=' ')
            return False

    if len(password) < 7:
        print("Password must be at least 7 characters long.", end=' ')
        return False

    count = 0

    # check lowercase, uppercase, digits, special characters
    checks = ["[a-z]", "[A-Z]", "\d", "[@$!%*#?&]"]
    for regex in checks:
        if re.search(regex, password):
            count += 1

    # check unicode: if the password contains unicode characters, 
    # it will change when encoded to utf-8 to one of [\u00d8-\u00f6]
    if f'b\'{password}\'' != f'{password.encode("utf-8")}':
       count += 1

    if (count > 2):
        return True
    print("Password does not meet the complexity requirements.", end=' ')
    return False
