import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swastik_mobile_app/core/utils/responsive_utils.dart';
import 'package:swastik_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:swastik_mobile_app/features/settings/presentation/widgets/avatar_widget.dart';
import 'package:swastik_mobile_app/features/settings/providers/profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  int _selectedGradient = 0;
  int _selectedIcon = -1; // -1 represents Monogram
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final profile = ref.watch(activeProfileProvider);
      _nameController = TextEditingController(text: profile.name);
      _selectedGradient = profile.gradientIndex;
      _selectedIcon = profile.iconIndex;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = AppResponsive.isTablet(context);
    final currentStaff = ref.watch(currentUserProfileProvider);
    final userId = currentStaff?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE), // Warm beige background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E1E1E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.montserrat(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32.0 : 20.0,
            vertical: isTablet ? 24.0 : 16.0,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ─── LIVE PREVIEW ──────────────────────────────────
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: _nameController,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Subtle glowing ring around preview
                        Container(
                          width: isTablet ? 140 : 110,
                          height: isTablet ? 140 : 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFD4B13B).withValues(alpha: 0.3),
                              width: 3,
                            ),
                          ),
                        ),
                        UserAvatar(
                          name: _nameController.text,
                          gradientIndex: _selectedGradient,
                          iconIndex: _selectedIcon,
                          size: isTablet ? 120 : 96,
                          fontSize: isTablet ? 42 : 36,
                          iconSize: isTablet ? 54 : 44,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // ─── PROFILE FIELDS CARD ────────────────────────────
                Container(
                  padding: EdgeInsets.all(isTablet ? 24 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                    border: Border.all(
                      color: const Color(0xFFE5DEC9).withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Name',
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 15 : 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8A7311),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 16 : 15,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E1E1E),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter name',
                          hintStyle: GoogleFonts.montserrat(
                            color: Colors.grey[400],
                            fontSize: isTablet ? 16 : 15,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFAF6EE),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _nameController.clear(),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── CHOOSE AVATAR STYLE ────────────────────────────
                Container(
                  padding: EdgeInsets.all(isTablet ? 24 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                    border: Border.all(
                      color: const Color(0xFFE5DEC9).withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Avatar Background',
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 15 : 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8A7311),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Horizontal list of gradients
                      SizedBox(
                        height: 54,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: AvatarHelper.gradients.length,
                          itemBuilder: (context, index) {
                            final colors = AvatarHelper.gradients[index];
                            final isSelected = _selectedGradient == index;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedGradient = index;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 14),
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: colors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colors[0].withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Choose Avatar Icon',
                        style: GoogleFonts.montserrat(
                          fontSize: isTablet ? 15 : 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8A7311),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Wrapped list of icons
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Monogram Option
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedIcon = -1;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _selectedIcon == -1
                                    ? const Color(0xFFFFF3D0)
                                    : const Color(0xFFFAF6EE),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedIcon == -1
                                      ? const Color(0xFFD4B13B)
                                      : const Color(0xFFE5DEC9).withValues(alpha: 0.5),
                                  width: _selectedIcon == -1 ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: AnimatedBuilder(
                                animation: _nameController,
                                builder: (context, _) {
                                  final initial = _nameController.text.isNotEmpty
                                      ? _nameController.text[0].toUpperCase()
                                      : 'U';
                                  return Text(
                                    initial,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedIcon == -1
                                          ? const Color(0xFF8A7311)
                                          : Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Custom Preset Icons
                          ...List.generate(AvatarHelper.icons.length, (index) {
                            final icon = AvatarHelper.icons[index];
                            final isSelected = _selectedIcon == index;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedIcon = index;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFFF3D0)
                                      : const Color(0xFFFAF6EE),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFD4B13B)
                                        : const Color(0xFFE5DEC9).withValues(alpha: 0.5),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  icon,
                                  color: isSelected
                                      ? const Color(0xFF8A7311)
                                      : Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // ─── SAVE BUTTON ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: isTablet ? 58 : 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final notifier = ref.read(profileProvider(userId).notifier);
                        await notifier.updateProfile(
                          name: _nameController.text.trim(),
                          gradientIndex: _selectedGradient,
                          iconIndex: _selectedIcon,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Profile updated successfully!',
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: const Color(0xFF0F9B0F),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDFBA6B), // Swastik gold
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isTablet ? 18 : 14),
                      ),
                    ),
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.montserrat(
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF01565B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
