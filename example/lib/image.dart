import 'dart:async' show Future, StreamController, scheduleMicrotask;
import 'dart:io';
import 'dart:ui'
    show BlendMode, Codec, Color, FilterQuality, ImmutableBuffer, TextDirection;

import 'package:flutter/foundation.dart'
    show
        DiagnosticsNode,
        DiagnosticsProperty,
        Key,
        SynchronousFuture,
        Uint8List,
        objectRuntimeType;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart' show LazyBox;
import 'package:http/http.dart' as http;
import 'package:octo_image/octo_image.dart' show OctoImage;
import 'package:shimmer/shimmer.dart' show Shimmer;
import 'dedup.dart' show DedupAsync;

late LazyBox<Uint8List> _box;
void initImageCache(LazyBox<Uint8List> box) {
  _box = box;
}

Widget buildImage(Uri uri, double? w, double? h, {
  double maxWidth = 100,
}) {
  final width = w ?? maxWidth;
  final height = h ?? width * 0.5625; // 1080p
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    //return Image.network(uri.toString(), width: width, height: height);
    return CachedImage(
      imageUrl: uri.toString(),
      borderRadius: BorderRadius.zero,
      height: height,
      width: width,
      boxFit: BoxFit.fitWidth,
    );
  } else if (uri.scheme == 'data') {
    if (uri.data!.mimeType.startsWith('image/')) {
      return Image.memory(
        uri.data!.contentAsBytes(),
        width: width,
        height: height,
      );
    }
    return const SizedBox.shrink();
  } else if (uri.scheme == 'resource') {
    return Image.asset(uri.path, width: width, height: height);
  } else {
    return Image.file(File.fromUri(uri), width: width, height: height);
  }
}

class CachedImage extends StatelessWidget {
  const CachedImage({
    Key? key,
    required this.imageUrl,
    required this.borderRadius,
    required this.height,
    required this.width,
    required this.boxFit,
  }) : super(key: key);

  final String imageUrl;
  final BorderRadiusGeometry borderRadius;
  final double height;
  final double width;
  final BoxFit boxFit;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: boxFit,
      placeholder: (context, url) => SizedBox(
        width: width,
        height: height,
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: borderRadius,
            ),
          ),
        ),
      ),
      imageBuilder: (context, imageProvider) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: imageProvider,
            fit: boxFit,
          ),
          borderRadius: borderRadius,
        ),
      ),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }
}

/// Builder function to create an image widget. The function is called after
/// the ImageProvider completes the image loading.
typedef ImageWidgetBuilder = Widget Function(
  BuildContext context,
  ImageProvider imageProvider,
);

/// Builder function to create a placeholder widget. The function is called
/// once while the ImageProvider is loading the image.
typedef PlaceholderWidgetBuilder = Widget Function(
  BuildContext context,
  String url,
);

/// Builder function to create a progress indicator widget. The function is
/// called every time a chuck of the image is downloaded from the web, but at
/// least once during image loading.
// typedef ProgressIndicatorBuilder = Widget Function(
//   BuildContext context,
//   String url,
//   DownloadProgress progress,
// );

/// Builder function to create an error widget. This builder is called when
/// the image failed loading, for example due to a 404 NotFound exception.
typedef LoadingErrorWidgetBuilder = Widget Function(
  BuildContext context,
  String url,
  dynamic error,
);

Widget _emptyPlaceholder(BuildContext context) => const SizedBox.shrink();

class CachedNetworkImage extends StatelessWidget {
  /*
  /// Get the current log level of the cache manager.
  static CacheManagerLogLevel get logLevel => CacheManager.logLevel;

  /// Set the log level of the cache manager to a [CacheManagerLogLevel].
  static set logLevel(CacheManagerLogLevel level) =>
      CacheManager.logLevel = level;

  /// Evict an image from both the disk file based caching system of the
  /// [BaseCacheManager] as the in memory [ImageCache] of the [ImageProvider].
  /// [url] is used by both the disk and memory cache. The scale is only used
  /// to clear the image from the [ImageCache].
  static Future evictFromCache(
    String url, {
    String? cacheKey,
    BaseCacheManager? cacheManager,
    double scale = 1.0,
  }) async {
    cacheManager = cacheManager ?? DefaultCacheManager();
    await cacheManager.removeFile(cacheKey ?? url);
    return CachedNetworkImageProvider(url, scale: scale).evict();
  }
  */

  //final CachedNetworkImageProvider _image;
  final ImageProvider _image;

  /// Option to use cachemanager with other settings
  //final BaseCacheManager? cacheManager;

  /// The target image that is displayed.
  final String imageUrl;

  /// The target image's cache key.
  //final String? cacheKey;

  /// Optional builder to further customize the display of the image.
  final ImageWidgetBuilder? imageBuilder;

  /// Widget displayed while the target [imageUrl] is loading.
  final PlaceholderWidgetBuilder? placeholder;

  /// Widget displayed while the target [imageUrl] is loading.
  //final ProgressIndicatorBuilder? progressIndicatorBuilder;

  /// Widget displayed while the target [imageUrl] failed loading.
  final LoadingErrorWidgetBuilder? errorWidget;

  /// The duration of the fade-in animation for the [placeholder].
  final Duration? placeholderFadeInDuration;

  /// The duration of the fade-out animation for the [placeholder].
  final Duration? fadeOutDuration;

  /// The curve of the fade-out animation for the [placeholder].
  final Curve fadeOutCurve;

  /// The duration of the fade-in animation for the [imageUrl].
  final Duration fadeInDuration;

  /// The curve of the fade-in animation for the [imageUrl].
  final Curve fadeInCurve;

  /// If non-null, require the image to have this width.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder widget does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double? width;

  /// If non-null, require the image to have this height.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder widget does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double? height;

  /// How to inscribe the image into the space allocated during layout.
  ///
  /// The default varies based on the other fields. See the discussion at
  /// [paintImage].
  final BoxFit? fit;

  /// How to align the image within its bounds.
  ///
  /// The alignment aligns the given position in the image to the given position
  /// in the layout bounds. For example, a [Alignment] alignment of (-1.0,
  /// -1.0) aligns the image to the top-left corner of its layout bounds, while a
  /// [Alignment] alignment of (1.0, 1.0) aligns the bottom right of the
  /// image with the bottom right corner of its layout bounds. Similarly, an
  /// alignment of (0.0, 1.0) aligns the bottom middle of the image with the
  /// middle of the bottom edge of its layout bounds.
  ///
  /// If the [alignment] is [TextDirection]-dependent (i.e. if it is a
  /// [AlignmentDirectional]), then an ambient [Directionality] widget
  /// must be in scope.
  ///
  /// Defaults to [Alignment.center].
  ///
  /// See also:
  ///
  ///  * [Alignment], a class with convenient constants typically used to
  ///    specify an [AlignmentGeometry].
  ///  * [AlignmentDirectional], like [Alignment] for specifying alignments
  ///    relative to text direction.
  final Alignment alignment;

  /// How to paint any portions of the layout bounds not covered by the image.
  final ImageRepeat repeat;

  /// Whether to paint the image in the direction of the [TextDirection].
  ///
  /// If this is true, then in [TextDirection.ltr] contexts, the image will be
  /// drawn with its origin in the top left (the "normal" painting direction for
  /// children); and in [TextDirection.rtl] contexts, the image will be drawn with
  /// a scaling factor of -1 in the horizontal direction so that the origin is
  /// in the top right.
  ///
  /// This is occasionally used with children in right-to-left environments, for
  /// children that were designed for left-to-right locales. Be careful, when
  /// using this, to not flip children with integral shadows, text, or other
  /// effects that will look incorrect when flipped.
  ///
  /// If this is true, there must be an ambient [Directionality] widget in
  /// scope.
  final bool matchTextDirection;

  /// Optional headers for the http request of the image url
  //final Map<String, String>? httpHeaders;

  /// When set to true it will animate from the old image to the new image
  /// if the url changes.
  final bool useOldImageOnUrlChange;

  /// If non-null, this color is blended with each image pixel using [colorBlendMode].
  final Color? color;

  /// Used to combine [color] with this image.
  ///
  /// The default is [BlendMode.srcIn]. In terms of the blend mode, [color] is
  /// the source and this image is the destination.
  ///
  /// See also:
  ///
  ///  * [BlendMode], which includes an illustration of the effect of each blend mode.
  final BlendMode? colorBlendMode;

  /// Target the interpolation quality for image scaling.
  ///
  /// If not given a value, defaults to FilterQuality.low.
  final FilterQuality filterQuality;

  /// Will resize the image in memory to have a certain width using [ResizeImage]
  final int? memCacheWidth;

  /// Will resize the image in memory to have a certain height using [ResizeImage]
  final int? memCacheHeight;

  /// Will resize the image and store the resized image in the disk cache.
  final int? maxWidthDiskCache;

  /// Will resize the image and store the resized image in the disk cache.
  final int? maxHeightDiskCache;

  /// CachedNetworkImage shows a network image using a caching mechanism. It also
  /// provides support for a placeholder, showing an error and fading into the
  /// loaded image. Next to that it supports most features of a default Image
  /// widget.
  CachedNetworkImage({
    Key? key,
    required this.imageUrl,
    //this.httpHeaders,
    this.imageBuilder,
    this.placeholder,
    //this.progressIndicatorBuilder,
    this.errorWidget,
    this.fadeOutDuration = const Duration(milliseconds: 1000),
    this.fadeOutCurve = Curves.easeOut,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.fadeInCurve = Curves.easeIn,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    //this.cacheManager,
    this.useOldImageOnUrlChange = false,
    this.color,
    this.filterQuality = FilterQuality.low,
    this.colorBlendMode,
    this.placeholderFadeInDuration,
    this.memCacheWidth,
    this.memCacheHeight,
    //this.cacheKey,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
  })  : _image = CachedImageProvider(
          imageUrl,
          scale: 1.0,
          width: memCacheWidth ?? width?.toInt(),
          height: memCacheHeight ?? height?.toInt(),
          //headers: httpHeaders,
        ),
        super(key: key);
        /*
        _image = ResizeImage.resizeIfNeeded(
          width?.toInt(),
          height?.toInt(),
          NetworkImage(imageUrl, scale: 1.0),
        ),
        */
  //   ImageRenderMethodForWeb imageRenderMethodForWeb =
  //       ImageRenderMethodForWeb.HtmlImage,
  // }) : _image = CachedNetworkImageProvider(
  //         imageUrl,
  //         headers: httpHeaders,
  //         cacheManager: cacheManager,
  //         cacheKey: cacheKey,
  //         //imageRenderMethodForWeb: imageRenderMethodForWeb,
  //         maxWidth: maxWidthDiskCache,
  //         maxHeight: maxHeightDiskCache,
  //       ),
  //       super(key: key);

  @override
  Widget build(BuildContext context) {
    /*
    var octoPlaceholderBuilder =
        placeholder != null ? _octoPlaceholderBuilder : null;
    var octoProgressIndicatorBuilder =
        progressIndicatorBuilder != null ? _octoProgressIndicatorBuilder : null;

    ///If there is no placeholer OctoImage does not fade, so always set an
    ///(empty) placeholder as this always used to be the behaviour of
    ///CachedNetworkImage.
    if (octoPlaceholderBuilder == null &&
        octoProgressIndicatorBuilder == null) {
      octoPlaceholderBuilder = (context) => Container();
    }
    */

    return OctoImage(
      image: _image,
      imageBuilder: imageBuilder != null ? _octoImageBuilder : null,
      placeholderBuilder:
          placeholder != null ? _octoPlaceholderBuilder : _emptyPlaceholder,
      //progressIndicatorBuilder: octoProgressIndicatorBuilder,
      errorBuilder: errorWidget != null ? _octoErrorBuilder : null,
      fadeOutDuration: fadeOutDuration,
      fadeOutCurve: fadeOutCurve,
      fadeInDuration: fadeInDuration,
      fadeInCurve: fadeInCurve,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      matchTextDirection: matchTextDirection,
      color: color,
      filterQuality: filterQuality,
      colorBlendMode: colorBlendMode,
      placeholderFadeInDuration: placeholderFadeInDuration,
      gaplessPlayback: useOldImageOnUrlChange,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
    );
  }

  Widget _octoImageBuilder(BuildContext context, Widget child) {
    return imageBuilder!(context, _image);
  }

  Widget _octoPlaceholderBuilder(BuildContext context) {
    return placeholder!(context, imageUrl);
  }

  // Widget _octoProgressIndicatorBuilder(
  //   BuildContext context,
  //   ImageChunkEvent? progress,
  // ) {
  //   int? totalSize;
  //   var downloaded = 0;
  //   if (progress != null) {
  //     totalSize = progress.expectedTotalBytes;
  //     downloaded = progress.cumulativeBytesLoaded;
  //   }
  //   return progressIndicatorBuilder!(
  //       context, imageUrl, DownloadProgress(imageUrl, totalSize, downloaded));
  // }

  Widget _octoErrorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return errorWidget!(context, imageUrl, error);
  }
}

final _dedupLoadOrFetchImg = <String, DedupAsync<ImmutableBuffer>?>{};

Future<ImmutableBuffer> _loadOrFetchImg(String url) async {
  final image = await _box.get(url);
  if (image != null) {
    return ImmutableBuffer.fromUint8List(image);
  }
  //final Uri resolved = Uri.base.resolve(key.url);
  final res = await http.get(Uri.parse(url));
  final bytes = res.bodyBytes;
  if (bytes.lengthInBytes == 0) {
    throw Exception('NetworkImage is an empty file: $url');
  }
  await _box.put(url, bytes);
  //_box.put(url, bytes).catchError(noop);
  return ImmutableBuffer.fromUint8List(bytes);
}

Future<ImmutableBuffer> $loadOrFetchImg(String url) {
  var map = _dedupLoadOrFetchImg, d = map[url];
  d ??= DedupAsync(() => _loadOrFetchImg(url), url, map);
  return d.future;
}

class CachedImageProvider extends ImageProvider<NetworkImage>
    implements NetworkImage {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments [url] and [scale] must not be null.
  const CachedImageProvider(
    this.url, {
    this.scale = 1.0,
    this.width,
    this.height,
  });

  @override
  final String url;

  @override
  final double scale;
  
  final int? width;
  final int? height;

  @override
  Map<String, String>? get headers => null;

  @override
  Future<CachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadBuffer(
      NetworkImage key, DecoderBufferCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key as CachedImageProvider, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<NetworkImage>('Image key', key),
      ],
    );
  }

  Future<Codec> _loadAsync(
    CachedImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderBufferCallback decode,
  ) async {
    try {
      assert(key == this);
      final buffer = await $loadOrFetchImg(url);
      return decode(buffer, cacheWidth: width, cacheHeight: height);
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is CachedImageProvider &&
        other.url == url &&
        other.scale == scale &&
        other.width == width &&
        other.height == height;

  @override
  int get hashCode => Object.hash(url, scale, width, height);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'NetworkImage')}("$url", scale: $scale, width: $width, height: $height)';
}
