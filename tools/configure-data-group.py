#!/usr/bin/env python3
"""Configure only an approved AGC data-group-id; signing profile renewal is separate."""
import argparse
import json
from pathlib import Path
import re
parser = argparse.ArgumentParser()
parser.add_argument('data_group_id', help='Approved data-group-id from Huawei')
args = parser.parse_args()
if not re.fullmatch(r'[A-Za-z0-9_.-]{1,128}', args.data_group_id):
    parser.error('Invalid data-group-id')
root = Path(__file__).resolve().parents[1]
path = root / 'entry/src/main/module.json5'
module = json.loads(path.read_text())
for extension in module['module']['extensionAbilities']:
    if extension['name'] == 'InputMethodService': extension['dataGroupIds'] = [args.data_group_id]
path.write_text(json.dumps(module, ensure_ascii=False, indent=2) + '\n')
(root / 'entry/src/main/ets/ime/SharedSettingsConfig.ets').write_text(
    '// Approved AGC identifier; must also be present in the renewed signing profile.\n'
    + 'export const SETTINGS_GROUP_ID: string = ' + json.dumps(args.data_group_id) + ';\n')
print('Configured source and module. Renew the signing profile in DevEco before rebuilding/installing.')
