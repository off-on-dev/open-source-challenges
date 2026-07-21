import { useEffect } from 'react';
import { FieldExtensionComponentProps } from '@backstage/plugin-scaffolder-react';
import {
  FormFieldBlueprint,
  createFormField,
} from '@backstage/plugin-scaffolder-react/alpha';
import { createFrontendModule } from '@backstage/frontend-plugin-api';

/**
 * Marks the moment the captain opens the commission form. Renders nothing: on
 * mount it just stamps its field with the open time. The backend turns that into
 * the "enter parameters" bar (form open -> first scaffolder action), so the
 * commission trace opens with the human's form-fill time rather than the
 * scaffolder's first step. Best-effort: without it the value is simply absent
 * and the trace still works, just without the opening bar.
 */
function EnterParametersTimer(props: FieldExtensionComponentProps<string>) {
  const { onChange, formData } = props;
  useEffect(() => {
    if (!formData) {
      onChange(new Date().toISOString());
    }
    // capture once, on mount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return null;
}

const enterParametersTimerField = FormFieldBlueprint.make({
  name: 'enter-parameters-timer',
  params: {
    field: async () =>
      createFormField({
        name: 'EnterParametersTimer',
        component: EnterParametersTimer,
      }),
  },
});

export const scaffolderFieldsModule = createFrontendModule({
  pluginId: 'scaffolder',
  extensions: [enterParametersTimerField],
});
