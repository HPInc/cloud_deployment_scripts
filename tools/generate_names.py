# Copyright Teradici Corporation 2019;  © Copyright 2022 HP Development Company, L.P.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import names
import random
import string

PUNCT_NO_COMMA = string.punctuation.replace(",", "")

def randomStr(length=12):
    letters = string.ascii_letters + string.digits + PUNCT_NO_COMMA
    return ''.join(random.choice(letters) for i in range(length))

def main():
    parser = argparse.ArgumentParser(description='Generate user CSV file')
    parser.add_argument('n', type=int, help='number of users to generate')
    args = parser.parse_args()

    # Headers
    print ("firstname,lastname,username,password,isadmin")

    for i in range(args.n):
        name = names.get_full_name().split()
        username = name[0][0] + name[1]
        password = randomStr()
        line = name[0] + ',' + name[1] + ',' + username.lower() + ',' + password
        print (line)

if __name__ == "__main__":
    main()

