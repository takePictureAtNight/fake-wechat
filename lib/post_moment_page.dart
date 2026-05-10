import 'package:flutter/material.dart';

import 'api_client.dart';

class PostMomentPage extends StatefulWidget {
  const PostMomentPage({super.key});

  @override
  State<PostMomentPage> createState() => _PostMomentPageState();
}

class _PostMomentPageState extends State<PostMomentPage> {
  final _content = TextEditingController();
  String _vis = 'ALL';
  List<dynamic> _groups = [];
  final Set<int> _selectedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final g = await ApiClient.instance.get('/api/groups/mine') as List<dynamic>;
      setState(() => _groups = g);
    } catch (_) {}
  }

  Future<void> _submit() async {
    final text = _content.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入内容')));
      return;
    }
    if (_vis == 'GROUPS' && _selectedGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择至少一个群')));
      return;
    }
    try {
      await ApiClient.instance.post('/api/moments', {
        'content': text,
        'visibility': _vis,
        if (_vis == 'GROUPS') 'visibleGroupIds': _selectedGroups.toList(),
      });
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发表动态'),
        actions: [TextButton(onPressed: _submit, child: const Text('发表', style: TextStyle(color: Colors.white)))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _content,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(hintText: '这一刻的想法...', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
          const Text('谁可以看', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          RadioListTile<String>(
            title: const Text('所有好友可见'),
            value: 'ALL',
            groupValue: _vis,
            onChanged: (v) => setState(() => _vis = v!),
          ),
          RadioListTile<String>(
            title: const Text('仅自己可见'),
            value: 'SELF',
            groupValue: _vis,
            onChanged: (v) => setState(() => _vis = v!),
          ),
          RadioListTile<String>(
            title: const Text('选择的群成员可见'),
            value: 'GROUPS',
            groupValue: _vis,
            onChanged: (v) => setState(() => _vis = v!),
          ),
          if (_vis == 'GROUPS') ...[
            const Divider(),
            if (_groups.isEmpty)
              const Text('你还没有加入任何群', style: TextStyle(color: Colors.grey))
            else
              ..._groups.map((g) {
                final m = g as Map<String, dynamic>;
                final id = (m['id'] as num).toInt();
                final name = m['name'] as String? ?? '';
                return CheckboxListTile(
                  value: _selectedGroups.contains(id),
                  onChanged: (c) {
                    setState(() {
                      if (c == true) {
                        _selectedGroups.add(id);
                      } else {
                        _selectedGroups.remove(id);
                      }
                    });
                  },
                  title: Text(name),
                );
              }),
          ],
        ],
      ),
    );
  }
}
