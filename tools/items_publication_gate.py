"""Validate the saved exact-package gates for the items/journals Beta publication."""
import hashlib,json
def verify(root,artifact):
    proof=json.loads((root/'qa/items-release/verified.json').read_text(encoding='utf-8'))
    assert proof['version']==artifact['version']=='0.3.21-beta'
    assert proof['public']['sha256']==artifact['sha256'] and not artifact['debug']
    with open(artifact['exe'],'rb') as file:assert hashlib.file_digest(file,'sha256').hexdigest()==artifact['sha256']
    checks=proof['packaged_checks']
    expected=set('autosave campaign_saves beyond_core map_navigation map_background steam_images preferences_updates belongings sidebar_stability map_switch_input map_package_ui token_picker_input session_tools_ui wizard_avatars wizard_eyes public_beta'.split())
    assert checks['artifact']['sha256']==artifact['sha256'] and checks['ok']
    assert len(checks['tests'])==len(expected) and {item['test'] for item in checks['tests']}==expected
    assert all(item['ok'] and item['exit_code']==0 and not item['issues'] for item in checks['tests'])
    for name,count in [('item_network',3),('map_network',5)]:
        record=proof[name]
        assert record['ok'] and record['sha256']==artifact['sha256'] and len(record['results'])==count
        assert all(not row['errors'] and row['exit_code']==0 and row['checks']>0 for row in record['results'])
    assert not proof['icon']['errors'] and proof['icon']['exe']==artifact['exe']
    assert not artifact['preservation']['changed']
    return proof
