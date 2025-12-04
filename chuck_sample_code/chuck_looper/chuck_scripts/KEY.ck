// KEY.ck
// global KEY conductor Class
public class KEY
{
    // global variables
    float maj_scale[8];
    static float one, two, three, four, five, six, seven, eight;
    
    // get scale notes
    fun void get_scale(float root){
        root => one;
        one+2 => two;
        two+2 => three;
        three+1 => four;
        four+2 => five;
        five+2 => six;
        six+2 => seven;
        seven+1 => eight;
        
        [one, two, three, four, five, six, seven, eight] @=> maj_scale; 
    }
}
