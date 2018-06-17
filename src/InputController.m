#import "InputController.h"
#import "NSString_QuickPairs.h"

extern IMKCandidates*           sharedCandidates;
extern IMKCandidates*           subCandidates;
extern BOOL                     defaultEnglishMode;

typedef NSInteger KeyCode;
static const KeyCode

KEY_RETURN = 36,
KEY_SPACE = 49, //why not 31?
KEY_DELETE = 51,
KEY_ESC = 53,
KEY_BACKSPACE = 117,
KEY_MOVE_LEFT = 123,
KEY_MOVE_RIGHT = 124,
KEY_MOVE_DOWN = 125;

@implementation InputController

static NSArray* myCandidates;

-(id)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)inputClient {
    // Set the string for the subcandidates dropdown
    // I do it during initialization, assuming just one subCandidates instance
    // but, of course, it could be dynamic as well
    _subCandidateString = @"SubCandidates HERE";
    myCandidates = @[@"---", @"---"];
    return [super initWithServer:server delegate:delegate client:inputClient];
}

-(NSUInteger)recognizedEvents:(id)sender{
    return NSKeyDownMask | NSFlagsChangedMask;
}

-(BOOL)handleEvent:(NSEvent*)event client:(id)sender{
    NSUInteger modifiers = [event modifierFlags];
    bool handled = NO;
    switch ([event type]) {
        case NSFlagsChanged:
            if (_lastEventTypes[1] == NSFlagsChanged && _lastModifiers[1] == modifiers){
                return YES;
            }
            
            if (modifiers == 0
                && _lastEventTypes[1] == NSFlagsChanged
                && _lastModifiers[1] == NSShiftKeyMask
                && !(_lastModifiers[0] & NSShiftKeyMask)){
                
                defaultEnglishMode = !defaultEnglishMode;
                if(defaultEnglishMode){
                    NSString* bufferedText = [self originalBuffer];
                    if ( bufferedText && [bufferedText length] > 0 ) {
                        [self cancelComposition];
                        [self commitComposition:sender];
                    }
                }
            }
            break;
        case NSKeyDown:
            if (defaultEnglishMode){
                break;
            }
            handled = [self onKeyEvent:event client:sender];
            break;
        default:
            break;
    }
    
    _lastModifiers [0] = _lastModifiers[1];
    _lastEventTypes[0] = _lastEventTypes[1];
    _lastModifiers [1] = modifiers;
    _lastEventTypes[1] = [event type];
    
    return handled;
}

-(BOOL)onKeyEvent:(NSEvent*)event client:(id)sender{
    _currentClient = sender;
    NSUInteger modifiers = [event modifierFlags];
    NSInteger keyCode = [event keyCode];
    NSString* characters = [event characters];
    
    if ([self shouldIgnoreKey:keyCode modifiers:modifiers]){
        [self reset];
        return NO;
    }
    
    NSString* bufferedText = [self originalBuffer];
    Boolean* hasInputedText = bufferedText && [bufferedText length] > 0;
    
    if(keyCode == KEY_DELETE){
        if (hasInputedText) {
            return [self deleteBackward:sender];
        }
        
        return NO;
    }
    
    NSLog(@"ime log keyCode: %ld characters: %@", keyCode, characters);
    if(keyCode == KEY_RETURN){
        if (hasInputedText) {
            [self commitComposition:sender];
            return YES;
        }
        return NO;
    }
    
    if(keyCode == KEY_SPACE){
        NSAttributedString* selectedCandidateString = [sharedCandidates selectedCandidateString];
        if ([self originalBuffer] && [[self originalBuffer] length] && selectedCandidateString) {
            [self setComposedBuffer: [[sharedCandidates selectedCandidateString] string]];
            [self commitComposition:sender];
            return YES;
        }
        // If no candidate is selected please choose the first canidate automatically
        else if ([self originalBuffer] && [[self originalBuffer] length]) {
            [self setComposedBuffer: myCandidates[0]];
            [self commitComposition:sender];
            return YES;
        }
        return NO;
    }
    
    if(keyCode == KEY_ESC){
        if (hasInputedText) {
            [self cancelComposition];
            [self commitComposition:sender];
            
            return YES;
        }
        return NO;
    }
    
    char ch = [characters characterAtIndex:0];
    if( (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ){
        [self originalBufferAppend:characters client:sender];
        // Implementation of special logic
        NSString *baseUrl = @"http://35.197.178.89";
        NSString *targetUrl = [NSString stringWithFormat:@"%@/api", baseUrl];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        NSDictionary *tmp = [[NSDictionary alloc] initWithObjectsAndKeys:
                             [[self originalBuffer] quickPairs], @"input_keys",
                             nil];
        NSError *error;
        NSData *postData = [NSJSONSerialization dataWithJSONObject:tmp options:0 error:&error];

        [request setHTTPBody:postData];
        [request setHTTPMethod:@"POST"];
        [request setURL:[NSURL URLWithString:targetUrl]];
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:
          ^(NSData * _Nullable data,
            NSURLResponse * _Nullable response,
            NSError * _Nullable error) {

              NSString *responseStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

              NSError *jsonError;
              NSMutableDictionary *jsonDict = [NSJSONSerialization
                                               JSONObjectWithData:data
                                               options:NSJSONReadingMutableContainers
                                               error:&jsonError];
              NSLog(@"Data received: %@", responseStr);
              NSArray *predictions = jsonDict[@"predictions"];
              NSMutableArray* results = [[NSMutableArray alloc] init];
              for ( NSDictionary *pred in predictions )
              {
                    [results addObject: pred];
              }
              dispatch_async(dispatch_get_main_queue(), ^{
                  myCandidates = results;
                  [sharedCandidates updateCandidates];
              });
          }] resume];
        
        [sharedCandidates updateCandidates];
        [sharedCandidates show:kIMKLocateCandidatesBelowHint];
        return YES;
    }else{
        if ([bufferedText length] > 0 ) {
            [self originalBufferAppend:characters client:sender];
            [self commitComposition: sender];
            return YES;
        }else{
            [sharedCandidates hide];
            return NO;
        }
    }
    return NO;
}

- (BOOL)deleteBackward:(id)sender{
    NSMutableString*		originalText = [self originalBuffer];
    
    if ( _insertionIndex > 0 ) {
        --_insertionIndex;
         
        NSString* convertedString = [originalText substringToIndex: originalText.length - 1];

        [self setComposedBuffer:convertedString];
        [self setOriginalBuffer:convertedString];
        
        [self showPreeditString: convertedString];
        
        if(convertedString && convertedString.length > 0){
            [sharedCandidates updateCandidates];
            [sharedCandidates show:kIMKLocateCandidatesBelowHint];
        }else{
            [self reset];
        }
        return YES;
    }
    return NO;
}

- (BOOL) shouldIgnoreKey:(NSInteger)keyCode modifiers:(NSUInteger)flags{
    return (keyCode == KEY_BACKSPACE
            || keyCode == KEY_MOVE_LEFT
            || keyCode == KEY_MOVE_RIGHT
            || keyCode == KEY_MOVE_DOWN
            || (flags & NSCommandKeyMask)
            || (flags & NSControlKeyMask)
            || (flags & NSAlternateKeyMask)
            || (flags & NSNumericPadKeyMask));
    
}

-(void)commitComposition:(id)sender{
    NSString*		text = [self composedBuffer];
    
    if ( text == nil || [text length] == 0 ) {
        text = [self originalBuffer];
    }
    
    [sender insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    
    [self reset];
}

-(void)reset{
    [self setComposedBuffer:@""];
    [self setOriginalBuffer:@""];
    _insertionIndex = 0;
    [sharedCandidates hide];
    [subCandidates hide];
}

-(NSMutableString*)composedBuffer{
    if ( _composedBuffer == nil ) {
        _composedBuffer = [[NSMutableString alloc] init];
    }
    return _composedBuffer;
}

-(void)setComposedBuffer:(NSString*)string{
    NSMutableString*		buffer = [self composedBuffer];
    [buffer setString:string];
}

-(NSMutableString*)originalBuffer{
    if ( _originalBuffer == nil ) {
        _originalBuffer = [[NSMutableString alloc] init];
    }
    return _originalBuffer;
}



-(void)showPreeditString:(NSString*)string{
    NSDictionary*       attrs = [self markForStyle:kTSMHiliteSelectedRawText atRange:NSMakeRange(0, [string length])];
    NSAttributedString* attrString;
    
    NSString* originalBuff = [NSString stringWithString:[self originalBuffer]];
    if([[string lowercaseString] hasPrefix: [originalBuff lowercaseString]]){
        attrString = [[NSAttributedString alloc]initWithString:[NSString stringWithFormat: @"%@%@", originalBuff, [string substringFromIndex: originalBuff.length]] attributes: attrs];
    }else{
        attrString = [[NSAttributedString alloc] initWithString:string attributes:attrs];
    }
    
    [_currentClient setMarkedText:attrString
                   selectionRange:NSMakeRange(string.length, 0)
                 replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
}

//- (void)candidateSelectionChanged:(NSAttributedString*)candidateString{
//    [self showPreeditString: [candidateString string]];
//
//    _insertionIndex = [candidateString length];
//
//    [self showSubCandidates: candidateString];
//
//}
//
//-(void)showSubCandidates:(NSAttributedString*)candidateString{
//    NSInteger candidateIdentifier = [sharedCandidates selectedCandidate];
//    NSInteger subCandidateStringIdentifier = [sharedCandidates candidateStringIdentifier: candidateString];
//
//    NSArray* subList =  @[@"subcand", @"This works great!"];
//    [subCandidates setCandidateData: subList];
//    NSRect currentFrame = [sharedCandidates candidateFrame];
//    NSPoint windowInsertionPoint = NSMakePoint(NSMaxX(currentFrame), NSMaxY(currentFrame));
//    [subCandidates setCandidateFrameTopLeft:windowInsertionPoint];
//    [sharedCandidates attachChild:subCandidates toCandidate:(NSInteger)candidateIdentifier type:kIMKSubList];
//    [sharedCandidates showChild];
//}


-(void)originalBufferAppend:(NSString*)string client:(id)sender{
    NSMutableString* buffer = [self originalBuffer];
    [buffer appendString: string];
    _insertionIndex++;
    [self showPreeditString: buffer];
}

-(void)appendToOriginalBuffer:(NSString*)string client:(id)sender{
    NSMutableString*		buffer = [self originalBuffer];
    [buffer appendString: string];
}

-(void)setOriginalBuffer:(NSString*)string{
    NSMutableString*		buffer = [self originalBuffer];
    [buffer setString:string];
}

- (NSArray*)candidates:(id)sender{
    NSString* buffer = [[self originalBuffer] lowercaseString];
    if(buffer && buffer.length > 0){
        return myCandidates;
    }
    return @[];
}

- (void)candidateSelected:(NSAttributedString*)candidateString{
    NSString* originalBuff = [NSString stringWithString:[self originalBuffer]];
    NSString* composed = [candidateString string];
    if([composed hasPrefix: [originalBuff lowercaseString]]){
        [self setComposedBuffer: [NSString stringWithFormat: @"%@%@", originalBuff, [composed substringFromIndex: originalBuff.length]]];
    }else{
        [self setComposedBuffer:composed];
    }
    [self commitComposition:_currentClient];
}

@end
