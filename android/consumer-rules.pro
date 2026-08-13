# Consumer ProGuard/R8 rules shipped with this plugin, so apps that enable
# minification don't have to work out what flutter_compress needs.
#
# The plugin deliberately keeps this list minimal: it does no name-based
# reflection, no JNI and no serialization, so R8 can shrink it freely. The
# `::class.java` references in the sources are compile-time class literals, which
# R8 already tracks.

# Components declared in AndroidManifest.xml are instantiated by the framework
# from their fully-qualified name. AGP normally derives a keep rule from the
# merged manifest, but state it explicitly so the rule survives an app-level R8
# config that trims those derived keeps.
-keep class com.compress.all.flutter_compress.CompressionForegroundService { <init>(); }

# Media3 (Transformer/ExoPlayer) ships its own consumer rules with its artifacts;
# do not duplicate them here — a stale copy is worse than none.
