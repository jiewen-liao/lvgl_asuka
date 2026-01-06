#include "src/app/app_entry.h"

#include "lvgl/lvgl.h"
#include "lvgl/demos/lv_demos.h"

#include "src/app/my_app/app.h"

static void run_widgets_demo(void)
{
    lv_demo_widgets();
    lv_demo_widgets_start_slideshow();
}

static void run_benchmark_demo(void)
{
    lv_demo_benchmark();
}

static void run_my_app_app(void)
{
    app_my_app_run();
}

void app_entry_run(void)
{
#if defined(LVGL_APP_TARGET_DEMO_BENCHMARK)
    run_benchmark_demo();
#elif defined(LVGL_APP_TARGET_MY_APP)
    run_my_app_app();
#else
    run_widgets_demo();
#endif
}
