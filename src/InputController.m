#import "InputController.h"
#import "NSString_QuickPairs.h"

extern IMKCandidates*           sharedCandidates;
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
KEY_MOVE_DOWN = 125,
KEY_NUM1 = 18,
KEY_NUM2 = 19,
KEY_NUM3 = 20,
KEY_NUM4 = 21,
KEY_NUM5 = 23,
KEY_NUM6 = 22,
KEY_NUM7 = 26,
KEY_NUM8 = 28,
KEY_NUM9 = 25,
KEY_NUM0 = 29;

@implementation InputController

static NSArray* myCandidates;

-(id)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)inputClient {
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
        if ([self originalBuffer] && [[self originalBuffer] length]) {
            [self setComposedBuffer: myCandidates[0]];
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
    
    // Select and commit a candidate when a number key is pressed
    if ([self isNumberKey:keyCode modifiers:modifiers]){
        if ([self originalBuffer] && [[self originalBuffer] length]) {
            char ch = [characters characterAtIndex:0];
            [self setComposedBuffer: myCandidates[(ch - '0') - 1]];
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
              for ( NSString *pred in predictions )
              {
                    [results addObject: [pred stringByReplacingOccurrencesOfString:@" " withString:@""]];
              }
              dispatch_async(dispatch_get_main_queue(), ^{
                  myCandidates = results;
                  [sharedCandidates updateCandidates];
              });
          }] resume];
        
        [sharedCandidates updateCandidates];
        [sharedCandidates show:kIMKLocateCandidatesBelowHint];
        return YES;
    }
    else{
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

// When the down arrow key is pressed
- (void)moveDown:(id)sender
{
    [self selectCandidateByRowOffset:1];
}

// When the up arrow key is pressed
- (void)moveUp:(id)sender
{
    [self selectCandidateByRowOffset:-1];
}

// Move to a candidate row specified by a certain offset
// If that candidate is not located, move to first row
- (void)selectCandidateByRowOffset:(NSUInteger) offset {
    if (sharedCandidates) {
        NSInteger candidateIdentifier = [sharedCandidates selectedCandidate];
        NSInteger lineNumber = [sharedCandidates lineNumberForCandidateWithIdentifier:candidateIdentifier];
        NSInteger nextIdentifier = [sharedCandidates candidateIdentifierAtLineNumber:lineNumber+offset];
        if (nextIdentifier == NSNotFound) {
            nextIdentifier = [sharedCandidates candidateIdentifierAtLineNumber:0];
        }
        [sharedCandidates selectCandidateWithIdentifier:nextIdentifier];
    }
}

- (BOOL) isNumberKey:(NSInteger)keyCode modifiers:(NSUInteger)flags{
    return (keyCode == KEY_NUM1
            || keyCode == KEY_NUM2
            || keyCode == KEY_NUM3
            || keyCode == KEY_NUM4
            || keyCode == KEY_NUM5
            || keyCode == KEY_NUM6
            || keyCode == KEY_NUM7
            || keyCode == KEY_NUM8
            || keyCode == KEY_NUM9
            || keyCode == KEY_NUM0
            || (flags & NSNumericPadKeyMask));
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
