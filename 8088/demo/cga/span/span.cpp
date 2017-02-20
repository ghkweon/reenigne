#include "alfe/main.h"
#include "alfe/vectors.h"
#include "alfe/user.h"
#include "alfe/bitmap.h"

typedef Vector3<float> Point;

DWORD cgaColours[4] = {0, 0x55ffff, 0xff55ff, 0xffffff};

Point cubeCorners[8] = {
    Point(-1, -1, -1),
    Point(-1, -1,  1),
    Point(-1,  1, -1),
    Point(-1,  1,  1),
    Point( 1, -1, -1),
    Point( 1, -1,  1),
    Point( 1,  1, -1),
    Point( 1,  1,  1)};

class Quad
{
public:
    Quad(int p0, int p1, int p2, int p3, int colour)
      : _colour(colour)
    {
        _points[0] = p0;
        _points[1] = p1;
        _points[2] = p2;
        _points[3] = p3;
    }

    int _points[4];
    int _colour;
};

Quad cubeFaces[6] = {
    Quad(0, 4, 6, 2, 1),
    Quad(4, 5, 7, 6, 2),
    Quad(5, 1, 3, 7, 1),
    Quad(1, 0, 2, 3, 2),
    Quad(2, 6, 7, 3, 3),
    Quad(0, 1, 5, 4, 3)
};

class Projection
{
public:
    void init(float theta, float phi, float distance, Vector2<float> scale,
        Vector2<float> offset)
    {
        float st = sin(theta);
        float ct = cos(theta);
        float sp = sin(phi);
        float cp = cos(phi);
        Vector2<float> s = scale*distance;
        _xx = s.x*st;
        _xy = -s.y*cp*ct;
        _xz = -sp*ct;
        _yx = s.x*ct;
        _yy = s.y*cp*st;
        _yz = sp*st;
        _zy = s.y*sp;
        _zz = -cp;
        _distance = distance;
        _offset = offset;
    }
    Point modelToScreen(Point model)
    {
        Point r(
            _xx*model.x + _yx*model.y /*+ _zx*model.z*/,
            _xy*model.x + _yy*model.y + _zy*model.z,
            _xz*model.x + _yz*model.y + _zz*model.z + _distance);
        return Point(r.x/r.z + _offset.x, r.y/r.z + _offset.y, r.z);
    }
private:
    float _distance;
    Vector2<float> _offset;
    float _xx;
    float _xy;
    float _xz;
    float _yx;
    float _yy;
    float _yz;
    //float _zx;
    float _zy;
    float _zz;
};


class SpanWindow;

class SpanBitmapWindow : public BitmapWindow
{
public:
    SpanBitmapWindow() : _theta(0), _phi(0)
    {
    }
    void setSpanWindow(SpanWindow* window)
    {
        _spanWindow = window;
    }
    void paint()
    {
        _spanWindow->restart();
    }
    virtual void draw()
    {
        if (!_bitmap.valid())
            _bitmap = Bitmap<DWORD>(Vector(320, 200));

        _bitmap.fill(0);
        Projection p;
        _theta += 0.01;
        if (_theta >= tau)
            _theta -= tau;
        _phi += 0.01*(sqrt(5.0) + 1)/2;
        if (_phi >= tau)
            _phi -= tau;
        float ys = 99.5/sqrt(3.0);
        float xs = 6*ys/5;
        p.init(_theta, _phi, 5, Vector2<float>(xs, ys),
            Vector2<float>(159.5, 99.5));

        Point corners[8];
        for (int i = 0; i < 8; ++i)
            corners[i] = p.modelToScreen(cubeCorners[i]);

        for (int i = 0; i < 6; ++i) {
            Point p0 =
        }


        _bitmap = setNextBitmap(_bitmap);
        invalidate();
    }
private:
    SpanWindow* _spanWindow;
    Bitmap<DWORD> _bitmap;
    float _theta;
    float _phi;
};

class SpanWindow : public RootWindow
{
public:
    SpanWindow()
    {
        _bitmap.setSpanWindow(this);

        add(&_bitmap);
        add(&_animated);

        _animated.setDrawWindow(&_bitmap);
        _animated.setRate(60);
    }
    void restart() { _animated.restart(); }
    void create()
    {
        setText("CGA Span buffer");
        setInnerSize(Vector(320, 200));
        _bitmap.setTopLeft(Vector(0, 0));
        RootWindow::create();
        _animated.start();
    }
private:
    SpanBitmapWindow _bitmap;
    AnimatedWindow _animated;
};

class Program : public WindowProgram<SpanWindow>
{
};