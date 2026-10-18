import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omen_vault_v3/models/vault_entry.dart';
import 'package:omen_vault_v3/models/vault_record.dart';
import 'package:omen_vault_v3/services/database_service.dart';
import 'package:omen_vault_v3/services/vault_crypto_service.dart';
import 'package:omen_vault_v3/views/vault_home_screen.dart';

class EditEntryScreen extends ConsumerStatefulWidget {
  final VaultEntry? entry;
  final String masterPassword;

  const EditEntryScreen({super.key, this.entry, required this.masterPassword});

  @override
  ConsumerState<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends ConsumerState<EditEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _username;
  late String _password;
  late String _url;
  late String _notes;
  bool _isSaving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _title = widget.entry?.title ?? '';
    _username = widget.entry?.username ?? '';
    _password = widget.entry?.password ?? '';
    _url = widget.entry?.url ?? '';
    _notes = widget.entry?.notes ?? '';
  }

  Future<void> _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isSaving = true;
      });

      final dbService = ref.read(databaseServiceProvider);
      final cryptoService = ref.read(vaultCryptoServiceProvider);

      final entryToSave = VaultEntry(
        id: widget.entry?.id,
        firestoreId: widget.entry?.firestoreId,
        title: _title,
        username: _username,
        password: _password,
        url: _url,
        notes: _notes,
      );

      final entryJson = jsonEncode(entryToSave.toJson());
      final encryptedData = await cryptoService.encrypt(entryJson, widget.masterPassword);

      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      try {
        final record = VaultRecord(
          id: widget.entry?.id?.toString() ?? '',
          firestoreId: widget.entry?.firestoreId,
          encryptedData: encryptedData,
          timestamp: DateTime.now(),
        );

        await dbService.saveRecord(record);

        ref.refresh(vaultEntriesProvider);

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Entry saved successfully!')),
          );
          navigator.pop();
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error saving entry: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'New Entry' : 'Edit Entry'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveEntry,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a title' : null,
                onSaved: (value) => _title = value!,
              ),
              TextFormField(
                initialValue: _username,
                decoration: const InputDecoration(labelText: 'Username'),
                onSaved: (value) => _username = value!,
              ),
              TextFormField(
                initialValue: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                onSaved: (value) => _password = value!,
              ),
              TextFormField(
                initialValue: _url,
                decoration: const InputDecoration(labelText: 'URL'),
                onSaved: (value) => _url = value!,
              ),
              TextFormField(
                initialValue: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
                onSaved: (value) => _notes = value!,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
