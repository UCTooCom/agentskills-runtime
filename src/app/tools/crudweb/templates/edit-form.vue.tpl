<script lang="ts" setup>
import type { {{table_name}} } from '@/store/models/{{db_name}}'
import {
  TinyCol,
  Form as TinyForm,
  FormItem as TinyFormItem,
  Input as TinyInput,
  TinyRow,
  DatePicker as TinyDatePicker,
  Select as TinySelect,
} from '@opentiny/vue'
import { computed, reactive, ref, unref, watch } from 'vue'
import { removeNull, getChangedFields } from '@/utils/data'

const props = defineProps<{
  {{camelTableName}}Data: Partial<{{table_name}}>
  readonly: boolean
}>()

const rulesRequired = {
  required: true,
  trigger: 'blur',
}

const rulesNumber = {
  type: 'number',
  min: 0,
  trigger: 'blur',
}

{{edit_rules}}

const editForm = ref()

const originalData = ref<Partial<{{table_name}}>>({})

{{edit_form_data}}

watch(() => props.{{camelTableName}}Data, (newData) => {
  if (newData && Object.keys(newData).length > 0) {
    originalData.value = JSON.parse(JSON.stringify(newData))
    
    Object.assign(formData, {
{{watch_assignments}}
    })
  }
}, { immediate: true, deep: true })

{{status_options}}

function getFormData() {
  const currentData = {
    ...unref(formData),
{{number_fields_conversion}}
  } as Partial<{{table_name}}>
  
  console.log('=== getFormData Debug ===')
  console.log('originalData:', originalData.value)
  console.log('currentData:', currentData)
  
  if (originalData.value && originalData.value.id) {
    const changedFields = getChangedFields(originalData.value, currentData)
    console.log('changedFields:', changedFields)
    
    if (Object.keys(changedFields).length === 1 && changedFields.id) {
      console.log('No changes detected, returning null')
      return null
    }
    
    const result = removeNull(changedFields) as Partial<{{table_name}}>
    console.log('Final result (after removeNull):', result)
    return result
  }
  
  console.log('New mode, returning removeNull(currentData)')
  return removeNull(currentData) as Partial<{{table_name}}>
}

defineExpose({
  getFormData,
  valid: async () => editForm.value.validate(),
})
</script>

<template>
  <TinyForm
    ref="editForm"
    :display-only="props.readonly"
    :rules="rules"
    :model="formData"
    label-position="left"
    label-width="120px"
  >
{{edit_form_rows}}
  </TinyForm>
</template>