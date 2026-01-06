#include "src/app/my_app/app.h"

#include "lvgl/lvgl.h"

void app_my_app_ui_init(void);
void app_my_app_model_init(void);
void app_my_app_utils_init(void);

void app_my_app_run(void)
{
    app_my_app_utils_init();
    app_my_app_model_init();
    app_my_app_ui_init();
}
