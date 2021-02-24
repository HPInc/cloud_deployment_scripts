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

    password = None

    while password is None:
        password1 = getpass.getpass('Enter a password: ').strip()
        if not ad_password_validate(password1, username):
            print("Please try again.")
            continue
        for x in range(3):
            password2 = getpass.getpass('Re-enter the password: ').strip()
            if password1 == password2:
                password = password1
                break
            print(f'The passwords do not match. {(2-x)} tries left.')
        print('\n')

    return password

def ad_password_validate(password, username):

    # replace any hyphens with dash
    username_parsed = username.replace('—','-')

    username_parsed = re.split("[,.\-\_#\s\t]", username_parsed)
    for u in username_parsed:
        if len(u) < 3:
            continue
        if re.search(u, password, re.IGNORECASE):
            print("Password cannot contain username.", end=' ')
            return False
    
    if len(password) < 7:
        print("Password must be at least 7 characters long.", end=' ')
        return False
    
    check = []

    #check lowercase
    regex = "([a-z])"
    pattern = re.compile(regex)
    match = re.search(pattern, password)
    if match:
        check.append(regex)

    #check uppercase
    regex = "([A-Z])"
    pattern = re.compile(regex)
    match = re.search(pattern, password)
    if match:
        check.append(regex)

    #check number
    regex = "(\d)"
    pattern = re.compile(regex)
    match = re.search(pattern, password)
    if match:
        check.append(regex)

    #check special characters
    regex = "([@$!%*#?&])"
    pattern = re.compile(regex)
    match = re.search(pattern, password)
    if match:
        check.append(regex)

    #check unicode
    if f'b\'{password}\'' != f'{password.encode("utf-8")}':
        check.append("unicode")

    if (len(check) > 2):
        return True
    else:
        print("Password does not meet the complexity requirements.", end=' ')
        return False
    
