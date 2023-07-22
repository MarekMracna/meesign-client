import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meesign_core/meesign_model.dart';

import 'dart:io';

import '../routes.dart';
import '../util/chars.dart';

class SheetActionButton extends StatelessWidget {
  final Widget icon;
  final Widget title;
  final Function() onPressed;
  final bool enabled;

  const SheetActionButton({
    Key? key,
    required this.icon,
    required this.title,
    required this.onPressed,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          IconButton(
            onPressed: enabled ? onPressed : null,
            icon: icon,
          ),
          title,
        ],
      ),
    );
  }
}

class OptionTile extends StatelessWidget {
  final String title;
  final EdgeInsets padding;
  final List<Widget> children;

  const OptionTile({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
            ] +
            children,
      ),
    );
  }
}

class NewGroupPage extends StatefulWidget {
  const NewGroupPage({Key? key}) : super(key: key);

  @override
  State<NewGroupPage> createState() => _NewGroupPageState();
}

const int _minThreshold = 2;

class _NewGroupPageState extends State<NewGroupPage> {
  // TODO: store this in a Group object?
  int _threshold = _minThreshold;
  final List<Device> _members = [];
  final _nameController = TextEditingController();
  String? _nameErr, _memberErr;
  KeyType _keyType = KeyType.signPdf;
  Protocol _protocol = KeyType.signPdf.supportedProtocols.first;
  bool _advancedOptions = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (_nameErr != null) {
        setState(() {
          _nameErr = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _setThreshold(int value) =>
      _threshold = max(_minThreshold, min(value, _members.length));

  Iterable<Widget> get _memberChips sync* {
    for (final Device member in _members) {
      yield InputChip(
        label: Text(member.name),
        avatar: CircleAvatar(
          child: Text(
            member.name.initials,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        onDeleted: () {
          setState(() {
            _members.remove(member);
            _setThreshold(_threshold);
          });
        },
      );
    }
  }

  void _addMember(Object? member) {
    if (member is! Device) return;
    for (final m in _members) {
      if (m.id == member.id) return;
    }
    setState(() {
      _members.add(member);
      _memberErr = null;
    });
  }

  void _selectPeer(String route) async {
    final peer = await Navigator.pushNamed(context, route);
    _addMember(peer);
  }

  void _tryCreate() {
    if (_nameController.text.isEmpty) {
      setState(() {
        _nameErr = "Enter group name";
      });
    }
    if (_members.length < 2) {
      setState(() {
        _memberErr = "Add member";
      });
    }
    if (_nameErr != null || _memberErr != null) return;

    Navigator.pop(
      context,
      Group(
        const [],
        _nameController.text,
        _members,
        _threshold,
        _protocol,
        _keyType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Group'),
        actions: [
          IconButton(
            onPressed: _tryCreate,
            icon: const Icon(Icons.send),
            tooltip: 'Create',
          ),
        ],
      ),
      body: ListView(
        children: [
          OptionTile(
            title: 'Name',
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  // labelText: 'Name',
                  border: const OutlineInputBorder(),
                  errorText: _nameErr,
                ),
                maxLength: 32,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(
                    RegExp('[${RegExp.escape(asciiPunctuationChars)}]'),
                  )
                ],
              ),
            ],
          ),
          OptionTile(
            title: 'Members',
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    // TODO: https://github.com/flutter/flutter/issues/118619
                    constraints: const BoxConstraints(maxWidth: 640),
                    builder: (context) {
                      return SizedBox(
                        height: 150,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SheetActionButton(
                              icon: const Icon(Icons.qr_code),
                              title: const Text('Scan'),
                              enabled: Platform.isAndroid || Platform.isIOS,
                              onPressed: () => _selectPeer(Routes.newGroupQr),
                            ),
                            SheetActionButton(
                              icon: const Icon(Icons.contactless_outlined),
                              title: const Text('Card'),
                              enabled: false,
                              onPressed: () => _selectPeer(Routes.newGroupCard),
                            ),
                            SheetActionButton(
                              icon: const Icon(Icons.search),
                              title: const Text('Search'),
                              onPressed: () =>
                                  _selectPeer(Routes.newGroupSearch),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                label: const Text('Add'),
                icon: const Icon(Icons.add),
                style: _memberErr != null
                    ? FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.errorContainer)
                    : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _memberChips.toList(),
              ),
            ],
          ),
          OptionTile(
            title: 'Threshold',
            children: [
              Row(
                children: [
                  const Icon(Icons.person),
                  Expanded(
                    child: Slider(
                      value: min(_threshold, _members.length).toDouble(),
                      min: 0,
                      max: _members.length.toDouble(),
                      divisions: max(1, _members.length),
                      label: '$_threshold',
                      onChanged: _members.length > _minThreshold
                          ? (value) => setState(() {
                                _setThreshold(value.round());
                              })
                          : null,
                    ),
                  ),
                  const Icon(Icons.people),
                ],
              ),
            ],
          ),
          OptionTile(
            title: 'Purpose',
            children: [
              SegmentedButton<KeyType>(
                selected: {_keyType},
                onSelectionChanged: (value) {
                  setState(() => {
                        _protocol = value.first.supportedProtocols.first,
                        _keyType = value.first
                      });
                },
                segments: const [
                  ButtonSegment<KeyType>(
                    value: KeyType.signPdf,
                    label: Text('Sign PDF'),
                  ),
                  ButtonSegment<KeyType>(
                    value: KeyType.signChallenge,
                    label: Text('Challenge'),
                  ),
                  ButtonSegment<KeyType>(
                    value: KeyType.decrypt,
                    label: Text('Decrypt'),
                  )
                ],
              ),
            ],
          ),
          ExpansionPanelList(
            children: [
              ExpansionPanel(
                  headerBuilder: (context, isOpen) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16.0, horizontal: 8.0),
                      child: Text(
                        'Advanced options',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onBackground
                                  .withOpacity(0.5),
                            ),
                      ),
                    );
                  },
                  body: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      return SizedBox(
                        width: constraints.maxWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text('Protocol'),
                                ),
                                DropdownButton(
                                  isExpanded: true,
                                  value: _protocol,
                                  items: _keyType.supportedProtocols
                                      .map((Protocol item) {
                                    return DropdownMenuItem(
                                      value: item,
                                      child: Text(item.name.toUpperCase()),
                                    );
                                  }).toList(),
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                  onChanged: (Protocol? value) {
                                    setState(() {
                                      _protocol = value!;
                                    });
                                  },
                                )
                              ]),
                        ),
                      );
                    },
                  ),
                  canTapOnHeader: true,
                  isExpanded: _advancedOptions)
            ],
            expansionCallback: (_, isOpen) =>
                setState(() => _advancedOptions = !isOpen),
          ),
        ],
      ),
    );
  }
}
