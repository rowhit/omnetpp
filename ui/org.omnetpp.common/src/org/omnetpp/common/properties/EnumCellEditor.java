package org.omnetpp.common.properties;

import org.eclipse.jface.viewers.ComboBoxCellEditor;
import org.eclipse.swt.SWT;
import org.eclipse.swt.widgets.Composite;

public class EnumCellEditor extends ComboBoxCellEditor {
	
	Object[] values;
	
	public EnumCellEditor(Composite parent, String[] names, Object[] values) {
		super(parent, names, SWT.READ_ONLY);
		this.values = values;
	}

	@Override
	protected Object doGetValue() {
		int index = (Integer)super.doGetValue();
		return 0 <= index && index < values.length ? values[index] : null;
	}

	@Override
	protected void doSetValue(Object value) {
		if (value != null)
			for(int i = 0; i < values.length; ++i)
				if (value.equals(values[i])) {
					super.doSetValue(i);
					return;
				}
	}
}
