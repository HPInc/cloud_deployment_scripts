# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

net user Administrator "${admin_password}" /active:yes
Enable-PSRemoting -Force
winrm set winrm/config/service/auth '@{Basic="true"}'