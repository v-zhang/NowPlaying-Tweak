#import "SBStatusBarDataManager.h"
#import "SBStatusBarStateAggregator.h"

#import <SpringBoard/SBMediaController.h>
#import <SpringBoard/SBStatusBarTimeView.h>

#import <CaptainHook/CaptainHook.h>

static NSString *_title;
static NSDictionary *_info;

static enum TitleType {
	TITLE_TITLE = 0,
	TITLE_ARTIST,
	TITLE_TIME,
	TITLE_LAST
} _type = TITLE_TITLE;

static void updateTimeString() {
	if (%c(SBStatusBarStateAggregator)) {
		SBStatusBarStateAggregator *stateAggregator = [%c(SBStatusBarStateAggregator) sharedInstance];
		[stateAggregator _updateTimeItems];
	} else {
		SBStatusBarDataManager *dataManager = [objc_getClass("SBStatusBarDataManager") sharedDataManager];
		[dataManager _updateTimeString];
	}
}

static void updateTitle(CFRunLoopTimerRef timer, void *info) {
	_type = (_type + 1) % TITLE_LAST;

	switch (_type) {
		case TITLE_TITLE:
			_title = _info[@"title"];
			break;

		case TITLE_ARTIST:
			_title = _info[@"artist"];
			break;

		case TITLE_TIME:
			_title = nil;
			break;

		default:
			break;
	}

	updateTimeString();
}

#define UPDATE_INTERVAL 3.7f

static CFRunLoopTimerRef _timer = NULL;

static void startTimer() {
	_timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
									CFAbsoluteTimeGetCurrent() + UPDATE_INTERVAL,
									UPDATE_INTERVAL, 0, 0, updateTitle, NULL);
	CFRunLoopAddTimer(CFRunLoopGetMain(), _timer, kCFRunLoopCommonModes);
}

static void stopTimer() {
	if (_timer) {
		CFRunLoopTimerInvalidate(_timer);
		CFRelease(_timer);

		_timer = NULL;
	}
}

%group iOS7
#define IOS7_STATUS_ITEM_TIME_IPHONE 3
#define IOS7_STATUS_ITEM_TIME_IPAD 4

%hook SBStatusBarStateAggregator

-(void)_updateTimeItems {
	%orig;

	StatusBarData_iOS7 *data = CHIvarRef(self, _data, StatusBarData_iOS7);

	if (_title) {
		[_title getCString:data->timeString maxLength:64 encoding:NSUTF8StringEncoding];
	} else {
		NSString **actualTime = CHIvarRef(self, _timeItemTimeString, NSString *);
		[*actualTime getCString:data->timeString maxLength:64 encoding:NSUTF8StringEncoding];
	}

	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		[self _notifyItemChanged:IOS7_STATUS_ITEM_TIME_IPAD];
	} else {
		[self _notifyItemChanged:IOS7_STATUS_ITEM_TIME_IPHONE];
	}
}

%end
%end

%group iOS6
%hook SBStatusBarDataManager

- (void)_updateTimeString {
	%orig;

	StatusBarData *data = CHIvarRef(self, _data, StatusBarData);

	if (_title) {
		[_title getCString:data->timeString maxLength:64 encoding:NSUTF8StringEncoding];
	} else {
		NSString **actualTime = CHIvarRef(self, _timeItemTimeString, NSString *);
		[*actualTime getCString:data->timeString maxLength:64 encoding:NSUTF8StringEncoding];
	}

	[self _dataChanged];
}

%end
%end

%hook SBMediaController

-(void)setNowPlayingInfo:(NSDictionary *)info {
	%orig;

	_info = [info copy];

	if ([_info[@"playbackRate"] intValue]) {
		_title = _info[@"title"];
		if (!_timer) {
			startTimer();
		}
	} else {
		_title = nil;
		stopTimer();
	}

	updateTimeString();
}

%end

%ctor {
	%init;

	if (%c(SBStatusBarStateAggregator)) {
		%init(iOS7);
	} else {
		%init(iOS6);
	}	
}
