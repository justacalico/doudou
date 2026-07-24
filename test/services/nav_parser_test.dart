import 'package:doudou/models/album.dart';
import 'package:doudou/models/artist.dart';
import 'package:doudou/models/playlist.dart';
import 'package:doudou/services/nav_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nav', () {
    test('navigates a nested path', () {
      final root = {
        'a': {
          'b': {
            'c': 'found',
          }
        }
      };

      expect(nav(root, ['a', 'b', 'c']), 'found');
    });

    test('returns null when path is broken', () {
      final root = {'a': 1};

      expect(nav(root, ['a', 'b', 'c']), isNull);
    });

    test('supports integer indices in path', () {
      final root = {
        'list': [
          {'v': 1},
          {'v': 2},
        ]
      };

      expect(nav(root, ['list', 1, 'v']), 2);
    });

    test('returns null when navigating into a non-map', () {
      expect(nav({'a': 1}, ['a', 'b']), isNull);
    });

    test('returns root when path is empty', () {
      expect(nav({'a': 1}, []), {'a': 1});
    });

    test('returns null for null root', () {
      expect(nav(null, ['a']), isNull);
    });

    test('supports noneIfAbsent flag', () {
      expect(nav({'a': 1}, ['b'], noneIfAbsent: true), isNull);
    });
  });

  group('parseSongRuns', () {
    test('parses artist with navigationEndpoint', () {
      final runs = [
        {
          'text': 'Pink Floyd',
          'navigationEndpoint': {
            'browseEndpoint': {'browseId': 'UCpink'}
          }
        },
        {'text': ' • '},
      ];

      final parsed = parseSongRuns(runs);

      expect(parsed['artists'], isA<List>());
      expect(parsed['artists'].length, 1);
      expect(parsed['artists'][0]['name'], 'Pink Floyd');
      expect(parsed['artists'][0]['id'], 'UCpink');
    });

    test('parses album when browseId starts with MPRE', () {
      final runs = [
        {
          'text': 'Dark Side',
          'navigationEndpoint': {
            'browseEndpoint': {'browseId': 'MPREb_xxx'}
          }
        },
        {'text': ' • '},
      ];

      final parsed = parseSongRuns(runs);

      expect(parsed['album'], isNotNull);
      expect(parsed['album']['name'], 'Dark Side');
      expect(parsed['album']['id'], 'MPREb_xxx');
    });

    test('parses duration in MM:SS format', () {
      final runs = [
        {'text': '3:45'},
      ];

      final parsed = parseSongRuns(runs);

      expect(parsed['length'], '3:45');
      expect(parsed['duration_seconds'], 225);
    });

    test('parses duration in HH:MM:SS format', () {
      final runs = [
        {'text': '1:02:03'},
      ];

      final parsed = parseSongRuns(runs);

      expect(parsed['length'], '1:02:03');
      expect(parsed['duration_seconds'], 3723);
    });

    test('parses year', () {
      final runs = [
        {'text': '1973'},
      ];

      final parsed = parseSongRuns(runs);

      expect(parsed['year'], '1973');
    });

    test('parses views when matching pattern', () {
      final runs = [
        {'text': 'Some Artist'},
        {'text': ' • '},
        {'text': '1.5M views'},
      ];

      final parsed = parseSongRuns(runs);

      expect(parsed['views'], '1.5M');
    });

    test('adds artist without id when no navigationEndpoint', () {
      final runs = [
        {'text': 'Unknown Artist'},
      ];

      final parsed = parseSongRuns(runs);

      expect(parsed['artists'].length, 1);
      expect(parsed['artists'][0]['name'], 'Unknown Artist');
      expect(parsed['artists'][0]['id'], isNull);
    });
  });

  group('parseRelatedArtist', () {
    test('extracts artist info from data', () {
      final data = {
        'title': {
          'runs': [
            {
              'text': 'David Gilmour',
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'UCgilmour'}
              }
            }
          ]
        },
        'thumbnailRenderer': {
          'musicThumbnailRenderer': {
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://example.com/g.jpg'}
              ]
            }
          }
        },
      };

      final artist = parseRelatedArtist(data);

      expect(artist, isA<Artist>());
      expect(artist.name, 'David Gilmour');
      expect(artist.browseId, 'UCgilmour');
    });
  });

  group('parsePlaylist', () {
    test('extracts basic playlist info', () {
      final data = {
        'title': {
          'runs': [
            {
              'text': 'My Playlist',
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'PL123'}
              }
            }
          ]
        },
        'thumbnailRenderer': {
          'musicThumbnailRenderer': {
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://example.com/p.jpg'}
              ]
            }
          }
        },
        'subtitle': {
          'runs': [
            {'text': 'Description text'}
          ],
        },
      };

      final pl = parsePlaylist(data);

      expect(pl, isA<Playlist>());
      expect(pl.title, 'My Playlist');
      expect(pl.playlistId, 'PL123');
      expect(pl.description, contains('Description text'));
    });

    test('parses count and author when 3 subtitle runs', () {
      final data = {
        'title': {
          'runs': [
            {
              'text': 'Mix',
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'PLmix'}
              }
            }
          ]
        },
        'thumbnailRenderer': {
          'musicThumbnailRenderer': {
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://example.com/m.jpg'}
              ]
            }
          }
        },
        'subtitle': {
          'runs': [
            {
              'text': 'Author',
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'UCauthor'}
              }
            },
            {'text': ' • '},
            {'text': '50 songs'},
          ],
        },
      };

      final pl = parsePlaylist(data);

      expect(pl.playlistId, 'PLmix');
    });
  });

  group('parseAlbum', () {
    test('extracts album info', () {
      final data = {
        'title': {
          'runs': [
            {
              'text': 'The Wall',
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'MPREb_wall'}
              }
            }
          ]
        },
        'subtitle': {
          'runs': [
            {
              'text': 'Pink Floyd',
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'UCpink'}
              }
            },
            {'text': ' • '},
            {'text': '1979'},
            {'text': ' • '},
            {'text': 'Album'},
          ],
        },
        'thumbnailRenderer': {
          'musicThumbnailRenderer': {
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://example.com/w.jpg'}
              ]
            }
          }
        },
        'menu': {
          'menuRenderer': {
            'items': [
              {
                'menuNavigationItemRenderer': {
                  'navigationEndpoint': {
                    'watchPlaylistEndpoint': {'playlistId': 'PLwall'}
                  },
                  'icon': {'iconType': 'PLAY'},
                }
              }
            ]
          }
        },
      };

      final album = parseAlbum(data);

      expect(album, isA<Album>());
      expect(album.title, 'The Wall');
      expect(album.browseId, 'MPREb_wall');
    });
  });

  group('parseSingle', () {
    test('extracts single info with year', () {
      final data = {
        'title': {
          'runs': [
            {
              'text': 'Hey You',
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'MPREb_hey'}
              }
            }
          ]
        },
        'subtitle': {
          'runs': [
            {'text': '2024'},
            {'text': ' • '},
            {'text': 'Single'},
          ],
        },
        'thumbnailRenderer': {
          'musicThumbnailRenderer': {
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://example.com/s.jpg'}
              ]
            }
          }
        },
        'menu': {
          'menuRenderer': {
            'items': [
              {
                'menuNavigationItemRenderer': {
                  'navigationEndpoint': {
                    'watchPlaylistEndpoint': {'playlistId': 'PLhey'}
                  },
                  'icon': {'iconType': 'PLAY'},
                }
              }
            ]
          }
        },
      };

      final album = parseSingle(data);

      expect(album, isA<Album>());
      expect(album.title, 'Hey You');
      expect(album.browseId, 'MPREb_hey');
    });
  });

  group('getFlexColumnItem', () {
    test('returns renderer when text and runs present', () {
      final item = {
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'Hello'}
                ]
              }
            }
          }
        ],
      };

      final result = getFlexColumnItem(item, 0);

      expect(result, isNotEmpty);
      expect(result['text']['runs'][0]['text'], 'Hello');
    });

    test('returns empty map when index out of range', () {
      expect(getFlexColumnItem({'flexColumns': []}, 5), {});
    });

    test('returns empty map when text key missing', () {
      final item = {
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {},
          }
        ],
      };

      expect(getFlexColumnItem(item, 0), {});
    });

    test('returns empty map when runs key missing', () {
      final item = {
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {},
            }
          }
        ],
      };

      expect(getFlexColumnItem(item, 0), {});
    });
  });

  group('getSearchResultType', () {
    test('returns null for null input', () {
      expect(getSearchResultType(null, ['album']), isNull);
    });

    test('returns album for unknown types', () {
      expect(getSearchResultType('weird', ['artist', 'playlist']), 'album');
    });

    test('maps known types by index', () {
      final resultTypes = ['artist', 'playlist', 'song', 'video', 'station'];

      expect(getSearchResultType('artist', resultTypes), 'artist');
      expect(getSearchResultType('playlist', resultTypes), 'playlist');
      expect(getSearchResultType('song', resultTypes), 'song');
      expect(getSearchResultType('video', resultTypes), 'video');
      expect(getSearchResultType('station', resultTypes), 'station');
    });

    test('is case-insensitive', () {
      expect(getSearchResultType('ARTIST', ['artist']), 'artist');
    });
  });

  group('parseWatchPlaylistHome', () {
    test('extracts title, playlistId, thumbnails', () {
      final data = {
        'title': {
          'runs': [
            {'text': 'Radio Mix'}
          ]
        },
        'navigationEndpoint': {
          'watchPlaylistEndpoint': {'playlistId': 'RD123'}
        },
        'thumbnailRenderer': {
          'musicThumbnailRenderer': {
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://example.com/r.jpg'}
              ]
            }
          }
        },
      };

      final result = parseWatchPlaylistHome(data);

      expect(result['title'], 'Radio Mix');
      expect(result['playlistId'], 'RD123');
      expect(result['thumbnails'], isNotNull);
    });
  });

  group('parseWatchTrack', () {
    test('extracts track info from playlistPanelVideoRenderer', () {
      final data = {
        'videoId': 'vid1',
        'title': {
          'runs': [
            {'text': 'Track Title'}
          ]
        },
        'lengthText': {
          'runs': [
            {'text': '3:21'}
          ]
        },
        'thumbnail': {
          'thumbnails': [
            {'url': 'https://example.com/t.jpg'}
          ]
        },
        'navigationEndpoint': {
          'watchEndpoint': {
            'watchEndpointMusicSupportedConfigs': {
              'watchEndpointMusicConfig': {
                'musicVideoType': 'MUSIC_VIDEO_TYPE_ATV'
              }
            }
          }
        },
        'longBylineText': {
          'runs': [
            {'text': 'Artist Name'},
            {'text': ' • '},
            {'text': 'Album Name'},
            {'text': ' • '},
            {'text': '3:21'},
          ],
        },
      };

      final track = parseWatchTrack(data);

      expect(track['videoId'], 'vid1');
      expect(track['title'], 'Track Title');
      expect(track['length'], '3:21');
      expect(track['videoType'], 'MUSIC_VIDEO_TYPE_ATV');
    });
  });

  group('getTabBrowseId', () {
    test('returns browseId when tab is selectable', () {
      final renderer = {
        'tabs': [
          {
            'tabRenderer': {
              'endpoint': {
                'browseEndpoint': {'browseId': 'BR123'}
              }
            }
          }
        ],
      };

      expect(getTabBrowseId(renderer, 0), 'BR123');
    });

    test('returns null when tab is unselectable', () {
      final renderer = {
        'tabs': [
          {
            'tabRenderer': {
              'unselectable': true,
            }
          }
        ],
      };

      expect(getTabBrowseId(renderer, 0), isNull);
    });
  });

  group('parseChartsItemBrowseId', () {
    test('returns Trending for title containing Trending', () {
      final result = parseChartsItemBrowseId({
        'musicTwoRowItemRenderer': {
          'title': {
            'runs': [
              {
                'text': 'Trending Now',
                'navigationEndpoint': {
                  'browseEndpoint': {'browseId': 'BRtrend'}
                }
              }
            ]
          }
        }
      });

      expect(result['title'], 'Trending');
      expect(result['browseId'], 'BRtrend');
    });

    test('returns Top Music Videos for Daily Top title', () {
      final result = parseChartsItemBrowseId({
        'musicTwoRowItemRenderer': {
          'title': {
            'runs': [
              {
                'text': 'Daily Top 50',
                'navigationEndpoint': {
                  'browseEndpoint': {'browseId': 'BRtop'}
                }
              }
            ]
          }
        }
      });

      expect(result['title'], 'Top Music Videos');
      expect(result['browseId'], 'BRtop');
    });

    test('returns original title for other categories', () {
      final result = parseChartsItemBrowseId({
        'musicTwoRowItemRenderer': {
          'title': {
            'runs': [
              {
                'text': 'Top Songs',
                'navigationEndpoint': {
                  'browseEndpoint': {'browseId': 'BRsongs'}
                }
              }
            ]
          }
        }
      });

      expect(result['title'], 'Top Songs');
      expect(result['browseId'], 'BRsongs');
    });
  });

  group('parseMixedContent', () {
    test('returns empty list for empty input', () {
      expect(parseMixedContent([]), isEmpty);
    });

    test('handles description shelf rows without adding to items', () {
      // parseMixedContent parses description shelf title/contents but
      // does not add them to the returned items list (only carousel rows
      // are added). This test documents that behavior.
      final rows = [
        {
          'musicDescriptionShelfRenderer': {
            'header': {
              'runs': [
                {'text': 'About'}
              ]
            },
            'description': {
              'runs': [
                {'text': 'Some description'}
              ]
            },
          }
        },
      ];

      final result = parseMixedContent(rows);

      expect(result, isEmpty);
    });

    test('skips rows without contents', () {
      final rows = [
        {
          'musicCarouselShelfRenderer': {
            'header': {
              'musicCarouselShelfBasicHeaderRenderer': {
                'title': {
                  'runs': [
                    {'text': 'Empty'}
                  ]
                }
              }
            },
          }
        },
      ];

      final result = parseMixedContent(rows);

      expect(result, isEmpty);
    });
  });

  group('parseSongArtistsRuns', () {
    test('extracts multiple artists from runs with separators', () {
      final runs = [
        {
          'text': 'Artist A',
          'navigationEndpoint': {
            'browseEndpoint': {'browseId': 'UCa'}
          }
        },
        {'text': ' • '},
        {
          'text': 'Artist B',
          'navigationEndpoint': {
            'browseEndpoint': {'browseId': 'UCb'}
          }
        },
      ];

      final artists = parseSongArtistsRuns(runs);

      expect(artists.length, 2);
      expect(artists[0]['name'], 'Artist A');
      expect(artists[0]['id'], 'UCa');
      expect(artists[1]['name'], 'Artist B');
      expect(artists[1]['id'], 'UCb');
    });

    test('extracts single artist from runs without separator', () {
      final runs = [
        {
          'text': 'Solo Artist',
          'navigationEndpoint': {
            'browseEndpoint': {'browseId': 'UCsolo'}
          }
        },
      ];

      final artists = parseSongArtistsRuns(runs);

      expect(artists.length, 1);
      expect(artists[0]['name'], 'Solo Artist');
      expect(artists[0]['id'], 'UCsolo');
    });
  });

  group('parseSongArtists', () {
    test('returns null when flex item is empty', () {
      final data = {
        'flexColumns': [
          {'musicResponsiveListItemFlexColumnRenderer': {}},
          {'musicResponsiveListItemFlexColumnRenderer': {}},
        ],
      };

      expect(parseSongArtists(data, 1), isNull);
    });

    test('returns parsed artists when runs present', () {
      final data = {
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'Title'}
                ]
              }
            }
          },
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {
                    'text': 'Artist X',
                    'navigationEndpoint': {
                      'browseEndpoint': {'browseId': 'UCx'}
                    }
                  },
                  {'text': ' • '},
                  {
                    'text': 'Artist Y',
                    'navigationEndpoint': {
                      'browseEndpoint': {'browseId': 'UCy'}
                    }
                  },
                ]
              }
            }
          },
        ],
      };

      final artists = parseSongArtists(data, 1);

      expect(artists, isNotNull);
      expect(artists!.length, 2);
      expect(artists[0]['name'], 'Artist X');
      expect(artists[1]['name'], 'Artist Y');
    });
  });

  group('parseSongAlbum', () {
    test('returns album map when flex item has content', () {
      final data = {
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'Song'}
                ]
              }
            }
          },
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': 'Artist'}
                ]
              }
            }
          },
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {
                    'text': 'Album Name',
                    'navigationEndpoint': {
                      'browseEndpoint': {'browseId': 'MPREb_alb'}
                    }
                  }
                ]
              }
            }
          },
        ],
      };

      final album = parseSongAlbum(data, 2);

      expect(album, isNotNull);
      expect(album!['name'], 'Album Name');
      expect(album['id'], 'MPREb_alb');
    });

    test('returns null when flex item is empty', () {
      final data = {
        'flexColumns': [
          {'musicResponsiveListItemFlexColumnRenderer': {}},
          {'musicResponsiveListItemFlexColumnRenderer': {}},
          {'musicResponsiveListItemFlexColumnRenderer': {}},
        ],
      };

      expect(parseSongAlbum(data, 2), isNull);
    });
  });

  group('getBrowseId', () {
    test('returns browseId when navigationEndpoint present', () {
      final item = {
        'text': {
          'runs': [
            {
              'text': 'X',
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'BRx'}
              }
            }
          ]
        }
      };

      expect(getBrowseId(item, 0), 'BRx');
    });

    test('returns null when no navigationEndpoint', () {
      final item = {
        'text': {
          'runs': [
            {'text': 'No link'}
          ]
        }
      };

      expect(getBrowseId(item, 0), isNull);
    });
  });

  group('parseWatchPlaylist', () {
    test('skips unplayable tracks', () {
      final results = [
        {
          'playlistPanelVideoRenderer': {
            'videoId': 'v1',
            'unplayableText': 'Not available',
            'title': {
              'runs': [
                {'text': 'Unplayable'}
              ]
            },
            'longBylineText': {'runs': [{'text': 'X'}]},
          }
        },
        {
          'playlistPanelVideoRenderer': {
            'videoId': 'v2',
            'title': {
              'runs': [
                {'text': 'Playable'}
              ]
            },
            'lengthText': {
              'runs': [
                {'text': '3:00'}
              ]
            },
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://example.com/p.jpg'}
              ]
            },
            'navigationEndpoint': {
              'watchEndpointMusicSupportedConfigs': {
                'watchEndpointMusicConfig': {
                  'musicVideoType': 'MUSIC_VIDEO_TYPE_ATV'
                }
              }
            },
            'longBylineText': {
              'runs': [
                {'text': 'Artist'}
              ]
            },
          }
        },
      ];

      final tracks = parseWatchPlaylist(results);

      expect(tracks.length, 1);
    });

    test('skips entries without playlistPanelVideoRenderer', () {
      final results = [
        {'someOtherRenderer': {}},
      ];

      expect(parseWatchPlaylist(results), isEmpty);
    });
  });

  group('parsePlaylistItems', () {
    test('skips items without musicResponsiveListItemRenderer', () {
      final results = [
        {'otherRenderer': {}},
      ];

      expect(parsePlaylistItems(results), isEmpty);
    });

    test('skips Song deleted items', () {
      final results = [
        {
          'musicResponsiveListItemRenderer': {
            'playlistItemData': {'videoId': 'v1'},
            'flexColumns': [
              {
                'musicResponsiveListItemFlexColumnRenderer': {
                  'text': {
                    'runs': [
                      {'text': 'Song deleted'}
                    ]
                  }
                }
              },
              {'musicResponsiveListItemFlexColumnRenderer': {}},
              {'musicResponsiveListItemFlexColumnRenderer': {}},
            ],
            'thumbnail': {
              'musicThumbnailRenderer': {
                'thumbnail': {
                  'thumbnails': [
                    {'url': 'https://example.com/t.jpg'}
                  ]
                }
              }
            },
          }
        },
      ];

      expect(parsePlaylistItems(results), isEmpty);
    });

    test('parses a valid playlist item', () {
      final results = [
        {
          'musicResponsiveListItemRenderer': {
            'playlistItemData': {'videoId': 'v1'},
            'flexColumns': [
              {
                'musicResponsiveListItemFlexColumnRenderer': {
                  'text': {
                    'runs': [
                      {
                        'text': 'Song Title',
                        'navigationEndpoint': {
                          'watchEndpoint': {'videoId': 'v1'}
                        }
                      }
                    ]
                  }
                }
              },
              {
                'musicResponsiveListItemFlexColumnRenderer': {
                  'text': {
                    'runs': [
                      {
                        'text': 'Artist',
                        'navigationEndpoint': {
                          'browseEndpoint': {'browseId': 'UCa'}
                        }
                      }
                    ]
                  }
                }
              },
              {'musicResponsiveListItemFlexColumnRenderer': {}},
            ],
            'thumbnail': {
              'musicThumbnailRenderer': {
                'thumbnail': {
                  'thumbnails': [
                    {'url': 'https://example.com/t.jpg'}
                  ]
                }
              }
            },
          }
        },
      ];

      final songs = parsePlaylistItems(results);

      expect(songs.length, 1);
    });
  });

  group('parseContentList', () {
    test('maps each item through parseFunc', () {
      final results = [
        {'musicTwoRowItemRenderer': {'id': 1}},
        {'musicTwoRowItemRenderer': {'id': 2}},
      ];

      final parsed = parseContentList(results, (data) => data['id']);

      expect(parsed, [1, 2]);
    });
  });
}
